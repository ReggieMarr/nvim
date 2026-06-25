-- lua/utils/websocket.lua
-- Minimal WebSocket server using vim.uv (libuv).
--
-- Adapted from live-preview.nvim (MIT/GPL dual license):
--   https://github.com/brianhuster/live-preview.nvim
--   lua/livepreview/server/websocket.lua
--
-- Provides a push-based WebSocket relay that runs inside Neovim,
-- eliminating the need for an external Python process.

local uv = vim.uv or vim.loop
local bit = bit or require 'bit'

local M = {}

-- ── SHA1 via openssl (one-shot, only used during handshake) ──────────

---Compute raw SHA1 hash of a string using openssl.
---@param input string
---@return string  raw binary SHA1 (20 bytes)
local function sha1_binary(input)
  -- Use printf to avoid trailing newline, pipe through openssl
  local handle = io.popen("printf '%s' '" .. input:gsub("'", "'\\''") .. "' | openssl sha1 -binary 2>/dev/null", 'r')
  if not handle then
    error 'websocket: openssl not available for SHA1'
  end
  local raw = handle:read '*a'
  handle:close()
  return raw
end

-- ── WebSocket frame encoding ────────────────────────────────────────

---Encode a text message as a WebSocket frame.
---@param message string
---@return string  binary frame
local function encode_frame(message)
  local length = #message
  local frame = string.char(0x81) -- FIN + text opcode

  if length <= 125 then
    frame = frame .. string.char(length) .. message
  elseif length <= 65535 then
    frame = frame
      .. string.char(126)
      .. string.char(bit.rshift(length, 8), length % 256)
      .. message
  else
    frame = frame
      .. string.char(127)
      .. string.char(
        bit.rshift(length, 56),
        bit.rshift(length, 48) % 256,
        bit.rshift(length, 40) % 256,
        bit.rshift(length, 32) % 256,
        bit.rshift(length, 24) % 256,
        bit.rshift(length, 16) % 256,
        bit.rshift(length, 8) % 256,
        length % 256
      )
      .. message
  end

  return frame
end

---Decode a WebSocket frame (client -> server, masked).
---@param data string  raw bytes from client
---@return string|nil  decoded payload, or nil if invalid
local function decode_frame(data)
  if #data < 2 then
    return nil
  end

  local byte2 = string.byte(data, 2)
  local masked = bit.band(byte2, 0x80) ~= 0
  local payload_len = bit.band(byte2, 0x7F)
  local offset = 2

  if payload_len == 126 then
    if #data < 4 then return nil end
    payload_len = string.byte(data, 3) * 256 + string.byte(data, 4)
    offset = 4
  elseif payload_len == 127 then
    -- For our use case (short JSON messages), 64-bit length is overkill
    -- but handle it for correctness
    if #data < 10 then return nil end
    payload_len = 0
    for i = 3, 10 do
      payload_len = payload_len * 256 + string.byte(data, i)
    end
    offset = 10
  end

  local mask_key
  if masked then
    if #data < offset + 4 then return nil end
    mask_key = { string.byte(data, offset + 1, offset + 4) }
    offset = offset + 4
  end

  if #data < offset + payload_len then return nil end

  local payload = data:sub(offset + 1, offset + payload_len)
  if masked and mask_key then
    local decoded = {}
    for i = 1, #payload do
      decoded[i] = string.char(bit.bxor(string.byte(payload, i), mask_key[((i - 1) % 4) + 1]))
    end
    payload = table.concat(decoded)
  end

  return payload
end

-- ── WebSocket handshake ─────────────────────────────────────────────

local WS_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'

---Perform the WebSocket handshake on an accepted TCP client.
---@param client uv_tcp_t
---@param request string  raw HTTP upgrade request
---@return boolean  true if handshake succeeded
local function do_handshake(client, request)
  local key = request:match 'Sec%-WebSocket%-Key: ([^\r\n]+)'
  if not key then
    client:close()
    return false
  end

  local raw_hash = sha1_binary(key .. WS_GUID)
  local accept = vim.trim(vim.base64.encode(raw_hash))

  local response = 'HTTP/1.1 101 Switching Protocols\r\n'
    .. 'Upgrade: websocket\r\n'
    .. 'Connection: Upgrade\r\n'
    .. 'Sec-WebSocket-Accept: '
    .. accept
    .. '\r\n\r\n'
  client:write(response)
  return true
end

---Send CORS-enabled HTTP response (for non-WebSocket requests like health checks).
---@param client uv_tcp_t
---@param body string
local function send_http_response(client, body)
  local response = 'HTTP/1.1 200 OK\r\n'
    .. 'Content-Type: text/plain\r\n'
    .. 'Content-Length: ' .. #body .. '\r\n'
    .. 'Access-Control-Allow-Origin: *\r\n'
    .. 'Cache-Control: no-cache\r\n'
    .. 'Connection: close\r\n'
    .. '\r\n'
    .. body
  client:write(response, function()
    if not client:is_closing() then
      client:close()
    end
  end)
end

-- ── Public API ──────────────────────────────────────────────────────

---@class websocket.Server
---@field port number
---@field server uv_tcp_t|nil
---@field clients uv_tcp_t[]
---@field on_message fun(payload: string)|nil  callback for incoming messages
local Server = {}
Server.__index = Server

---Create a new WebSocket server.
---@param port number
---@return websocket.Server
function M.new(port)
  return setmetatable({
    port = port,
    server = nil,
    clients = {},
    on_message = nil,
  }, Server)
end

---Start listening.
---@return boolean ok
---@return string|nil error
function Server:start()
  local server = uv.new_tcp()
  if not server then
    return false, 'failed to create TCP socket'
  end

  local ok, err = server:bind('127.0.0.1', self.port)
  if not ok then
    server:close()
    return false, 'bind failed: ' .. tostring(err)
  end

  local self_ref = self
  server:listen(8, function(listen_err)
    if listen_err then
      return
    end

    local client = uv.new_tcp()
    if not client then return end
    server:accept(client)

    local ws_connected = false
    local buffer = ''

    client:read_start(function(read_err, data)
      if read_err or not data then
        -- Client disconnected
        self_ref:_remove_client(client)
        if not client:is_closing() then
          client:close()
        end
        return
      end

      if not ws_connected then
        -- First message: could be HTTP upgrade or plain HTTP
        buffer = buffer .. data
        if buffer:match '\r\n\r\n' then
          if buffer:match 'Upgrade: websocket' then
            if do_handshake(client, buffer) then
              ws_connected = true
              table.insert(self_ref.clients, client)
            end
          else
            -- Plain HTTP request — serve a health/status response
            send_http_response(client, 'nvim-review-relay')
          end
          buffer = ''
        end
      else
        -- WebSocket frame
        local payload = decode_frame(data)
        if payload and self_ref.on_message then
          vim.schedule(function()
            self_ref.on_message(payload)
          end)
        end
      end
    end)
  end)

  self.server = server
  return true, nil
end

---Send a text message to all connected WebSocket clients.
---@param message string
function Server:broadcast(message)
  local frame = encode_frame(message)
  local stale = {}
  for i, client in ipairs(self.clients) do
    if client:is_closing() then
      table.insert(stale, i)
    else
      client:write(frame)
    end
  end
  -- Clean up stale clients (iterate in reverse)
  for i = #stale, 1, -1 do
    table.remove(self.clients, stale[i])
  end
end

---Send a JSON message to all connected WebSocket clients.
---@param tbl table
function Server:broadcast_json(tbl)
  self:broadcast(vim.json.encode(tbl))
end

---Remove a client from the list.
---@param client uv_tcp_t
function Server:_remove_client(client)
  for i, c in ipairs(self.clients) do
    if c == client then
      table.remove(self.clients, i)
      return
    end
  end
end

---Stop the server and close all connections.
function Server:stop()
  for _, client in ipairs(self.clients) do
    if not client:is_closing() then
      client:close()
    end
  end
  self.clients = {}

  if self.server and not self.server:is_closing() then
    self.server:close()
  end
  self.server = nil
end

---Check if the server is running.
---@return boolean
function Server:is_running()
  return self.server ~= nil and not self.server:is_closing()
end

---Get the number of connected clients.
---@return number
function Server:client_count()
  return #self.clients
end

return M
