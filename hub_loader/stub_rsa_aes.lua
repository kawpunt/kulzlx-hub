-- Kulzlx RSA-AES stub (placeholders filled by obf-loader.js)
-- Public-key unwrap of AES-256 key, then CBC decrypt of loader source.

local NHEX = "{{NHEX}}"
local EHEX = "{{EHEX}}"
local WRAP = "{{WRAP}}"
local IVB64 = "{{IV}}"
local CTB64 = "{{CT}}"

local bit32 = bit32
local band, bxor, rshift, lshift = bit32.band, bit32.bxor, bit32.rshift, bit32.lshift
local byte, char, sub = string.byte, string.char, string.sub
local floor = math.floor

local function b64decode(data)
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	data = data:gsub("%s", ""):gsub("=", "")
	local out, buf, n = {}, 0, 0
	for i = 1, #data do
		local c = data:sub(i, i)
		local p = b:find(c, 1, true)
		if p then
			buf = lshift(buf, 6) + (p - 1)
			n += 6
			if n >= 8 then
				n -= 8
				out[#out + 1] = char(band(rshift(buf, n), 255))
			end
		end
	end
	return table.concat(out)
end

local function hexToBytes(h)
	h = h:gsub("%s", "")
	if #h % 2 == 1 then
		h = "0" .. h
	end
	local t = {}
	for i = 1, #h, 2 do
		t[#t + 1] = tonumber(h:sub(i, i + 1), 16)
	end
	return t
end

local function bytesToBin(t)
	local s = {}
	for i = 1, #t do
		s[i] = char(t[i])
	end
	return table.concat(s)
end

local BASE = 16777216
local function dstrip(a)
	local i = #a
	while i > 1 and a[i] == 0 do
		a[i] = nil
		i -= 1
	end
	return a
end

local function dfromBe(bytes)
	local a = { 0 }
	for i = 1, #bytes do
		local carry = bytes[i]
		for j = 1, #a do
			local v = a[j] * 256 + carry
			a[j] = v % BASE
			carry = floor(v / BASE)
		end
		while carry > 0 do
			a[#a + 1] = carry % BASE
			carry = floor(carry / BASE)
		end
	end
	return dstrip(a)
end

local function dtoBe(a, len)
	local bytes = {}
	local x = {}
	for i = 1, #a do
		x[i] = a[i]
	end
	while #x > 1 or x[1] ~= 0 do
		local rem = 0
		for i = #x, 1, -1 do
			local cur = rem * BASE + x[i]
			x[i] = floor(cur / 256)
			rem = cur % 256
		end
		bytes[#bytes + 1] = rem
		dstrip(x)
	end
	local out = {}
	for i = #bytes, 1, -1 do
		out[#out + 1] = bytes[i]
	end
	while #out < len do
		table.insert(out, 1, 0)
	end
	while #out > len do
		table.remove(out, 1)
	end
	return out
end

local function dcmp(a, b)
	if #a ~= #b then
		return #a > #b and 1 or -1
	end
	for i = #a, 1, -1 do
		if a[i] ~= b[i] then
			return a[i] > b[i] and 1 or -1
		end
	end
	return 0
end

local function dsub(a, b)
	local c, borrow = {}, 0
	local n = math.max(#a, #b)
	for i = 1, n do
		local v = (a[i] or 0) - (b[i] or 0) - borrow
		if v < 0 then
			v += BASE
			borrow = 1
		else
			borrow = 0
		end
		c[i] = v
	end
	return dstrip(c)
end

local function dshl(a)
	local c, carry = {}, 0
	for i = 1, #a do
		local v = a[i] * 2 + carry
		c[i] = v % BASE
		carry = floor(v / BASE)
	end
	if carry > 0 then
		c[#c + 1] = carry
	end
	return dstrip(c)
end

local function dshr(a)
	local c, carry = {}, 0
	for i = #a, 1, -1 do
		local v = a[i] + carry * BASE
		c[i] = floor(v / 2)
		carry = v % 2
	end
	return dstrip(c)
end

local function dmod(a, n)
	if dcmp(a, n) < 0 then
		return a
	end
	local m = {}
	for i = 1, #n do
		m[i] = n[i]
	end
	while dcmp(dshl(m), a) <= 0 do
		m = dshl(m)
	end
	while dcmp(a, n) >= 0 do
		if dcmp(a, m) >= 0 then
			a = dsub(a, m)
		end
		if dcmp(m, n) == 0 then
			break
		end
		m = dshr(m)
	end
	return a
end

local function dmul(a, b)
	local c = {}
	for i = 1, #a + #b do
		c[i] = 0
	end
	for i = 1, #a do
		local carry = 0
		for j = 1, #b do
			local k = i + j - 1
			local v = c[k] + a[i] * b[j] + carry
			c[k] = v % BASE
			carry = floor(v / BASE)
		end
		local k = i + #b
		while carry > 0 do
			local v = (c[k] or 0) + carry
			c[k] = v % BASE
			carry = floor(v / BASE)
			k += 1
		end
	end
	return dstrip(c)
end

local function dmodexp(base, exp, n)
	local r = { 1 }
	base = dmod(base, n)
	while dcmp(exp, { 0 }) > 0 do
		if band(exp[1], 1) == 1 then
			r = dmod(dmul(r, base), n)
		end
		base = dmod(dmul(base, base), n)
		exp = dshr(exp)
	end
	return r
end

local function rsaPublicDecrypt(cipher)
	local n = dfromBe(hexToBytes(NHEX))
	local e = dfromBe(hexToBytes(EHEX))
	local cbytes = {}
	for i = 1, #cipher do
		cbytes[i] = byte(cipher, i)
	end
	local c = dfromBe(cbytes)
	local m = dtoBe(dmodexp(c, e, n), #cipher)
	if m[1] ~= 0 or m[2] ~= 2 then
		error("rsa pad")
	end
	local i = 3
	while i <= #m and m[i] ~= 0 do
		i += 1
	end
	i += 1
	local out = {}
	for j = i, #m do
		out[#out + 1] = char(m[j])
	end
	return table.concat(out)
end

local function gfMul(a, b)
	local p = 0
	for _ = 1, 8 do
		if band(b, 1) ~= 0 then
			p = bxor(p, a)
		end
		local hi = band(a, 0x80)
		a = band(lshift(a, 1), 255)
		if hi ~= 0 then
			a = bxor(a, 0x1b)
		end
		b = rshift(b, 1)
	end
	return p
end

local SBOX = {
	0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
	0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
	0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
	0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
	0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
	0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
	0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
	0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
	0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
	0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
	0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
	0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
	0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
	0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
	0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
	0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16,
}

local INV_S = {}
for i = 0, 255 do
	INV_S[SBOX[i + 1]] = i
end

local RCON = { 0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36 }

local function keySchedule(key)
	local Nk, Nb, Nr = 8, 4, 14
	local w = {}
	for i = 0, Nk - 1 do
		w[i] = {
			byte(key, i * 4 + 1),
			byte(key, i * 4 + 2),
			byte(key, i * 4 + 3),
			byte(key, i * 4 + 4),
		}
	end
	for i = Nk, Nb * (Nr + 1) - 1 do
		local temp = { w[i - 1][1], w[i - 1][2], w[i - 1][3], w[i - 1][4] }
		if i % Nk == 0 then
			temp = { temp[2], temp[3], temp[4], temp[1] }
			for k = 1, 4 do
				temp[k] = SBOX[temp[k] + 1]
			end
			temp[1] = bxor(temp[1], RCON[floor(i / Nk)])
		elseif i % Nk == 4 then
			for k = 1, 4 do
				temp[k] = SBOX[temp[k] + 1]
			end
		end
		w[i] = {
			bxor(w[i - Nk][1], temp[1]),
			bxor(w[i - Nk][2], temp[2]),
			bxor(w[i - Nk][3], temp[3]),
			bxor(w[i - Nk][4], temp[4]),
		}
	end
	local bytes = {}
	for i = 0, Nb * (Nr + 1) - 1 do
		for k = 1, 4 do
			bytes[#bytes + 1] = w[i][k]
		end
	end
	return bytes
end

local function addRound(s, rk, off)
	for i = 1, 16 do
		s[i] = bxor(s[i], rk[off + i])
	end
end

local function invSub(s)
	for i = 1, 16 do
		s[i] = INV_S[s[i]]
	end
end

local function invShift(s)
	local t
	t = s[14]; s[14] = s[10]; s[10] = s[6]; s[6] = s[2]; s[2] = t
	t = s[15]; s[15] = s[7]; s[7] = t
	t = s[11]; s[11] = s[3]; s[3] = t
	t = s[16]; s[16] = s[4]; s[4] = s[8]; s[8] = s[12]; s[12] = t
end

local function invMix(s)
	for c = 0, 3 do
		local i = c * 4
		local a, b, d, e = s[i + 1], s[i + 2], s[i + 3], s[i + 4]
		s[i + 1] = bxor(gfMul(a, 14), gfMul(b, 11), gfMul(d, 13), gfMul(e, 9))
		s[i + 2] = bxor(gfMul(a, 9), gfMul(b, 14), gfMul(d, 11), gfMul(e, 13))
		s[i + 3] = bxor(gfMul(a, 13), gfMul(b, 9), gfMul(d, 14), gfMul(e, 11))
		s[i + 4] = bxor(gfMul(a, 11), gfMul(b, 13), gfMul(d, 9), gfMul(e, 14))
	end
end

local function decryptBlock(w, blk)
	local s = {}
	for i = 1, 16 do
		s[i] = byte(blk, i)
	end
	addRound(s, w, 224)
	for round = 13, 1, -1 do
		invShift(s)
		invSub(s)
		addRound(s, w, round * 16)
		invMix(s)
	end
	invShift(s)
	invSub(s)
	addRound(s, w, 0)
	return bytesToBin(s)
end

local function aesCbcDecrypt(key, iv, ct)
	local w = keySchedule(key)
	local prev = iv
	local out = {}
	for i = 1, #ct, 16 do
		local block = sub(ct, i, i + 15)
		local plain = decryptBlock(w, block)
		local x = {}
		for j = 1, 16 do
			x[j] = char(bxor(byte(plain, j), byte(prev, j)))
		end
		out[#out + 1] = table.concat(x)
		prev = block
	end
	local raw = table.concat(out)
	local pad = byte(raw, #raw)
	if pad < 1 or pad > 16 then
		error("aes pad")
	end
	return sub(raw, 1, #raw - pad)
end

local wrap = b64decode(WRAP)
local aesKey = rsaPublicDecrypt(wrap)
local iv = b64decode(IVB64)
local ct = b64decode(CTB64)
local src = aesCbcDecrypt(aesKey, iv, ct)
local fn, err = loadstring(src, "@kulzlx")
assert(fn, err)
return fn()
