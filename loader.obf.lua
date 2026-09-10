-- Kulzlx RSA-AES stub (placeholders filled by obf-loader.js)
-- Public-key unwrap of AES-256 key, then CBC decrypt of loader source.

local NHEX = "beaf66a2d73d1bdf1352d65f9e325ca10650217e3b772d33415d098b01a214f1dd531c604220099bb308ad7a0a7f2989a49b2063d431fbb0542bc84ac07ebaee905b22f0d7a62f59bea833402d3a602a615ac2d3a7a97c5cb56a306f9c6f66d43048ac29cea485d127e3f1fd7a38f8f003e63d3e497a1efa3c23185e24996a16e291d93d07aad79b5f7cb697b622df54d407a1985ba686b6ab43cadb570be5e8a522ba05614e17d1fa8847355afa78654c8592c3d5114ba4e25e3b85fd5a7167116ac764010200ba9570a4a2e5df458fa69efc314dfe85548af803c274e5e8c6dc780761008b4601f93845e5fb15301d8ea5bf1a2e82099348d6d99c1edd70c1"
local EHEX = "010001"
local WRAP = "TIX9IK32Ikbpq28Zu7KbFu3IMZsf5xKuwBgFZDaLX2KtTcgdbMaVM8QB9jw9ij/yO1eUnFOhNsCd8K2hWrxqFMtIRHGpL8eqS+wHtoBer3tp2zke4GZYlccejdSwHwZcwuTQPLkNpptzCHcKccF6QBPvbwChGpDNXvIpfBOCgpTnq59oy7/OF5WftWAtZq5TnYtjPtk1EjxaQPMhZbnBtD2nVXhiF0KCheBy/NT5EENZuOQDGE0Tg/GMZ7BMbDuElutTXiRm3zmYigYXrYqL5b+77mqhcu9yvDLECngV9r5+F0dy52pArL6Ryeyz/BbTG5Bw+Oh83BDGsd933QpPiw=="
local IVB64 = "fLma4zOFJbaGm8jMj1wyAA=="
local CTB64 = "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"

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
