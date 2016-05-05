
do

local function check_int(n)
  if(n - math.floor(n) > 0) then error("trying to use bitwise operation on non-integer!") end
end

local function to_bits(n)
 check_int(n)
 if(n < 0) then  return to_bits(bit.bnot(math.abs(n)) + 1) end
 -- to bits table
 local tbl = {}
 local cnt = 1
 while (n > 0) do
  local last = math.mod(n,2)
  if(last == 1) then
   tbl[cnt] = 1
  else
   tbl[cnt] = 0
  end
  n = (n-last)/2
  cnt = cnt + 1
 end

 return tbl
end

local function tbl_to_number(tbl)
 local n = table.getn(tbl)

 local rslt = 0
 local power = 1
 for i = 1, n do
  rslt = rslt + tbl[i]*power
  power = power*2
 end
 
 return rslt
end

local function expand(tbl_m, tbl_n)
 local big = {}
 local small = {}
 if(table.getn(tbl_m) > table.getn(tbl_n)) then
  big = tbl_m
  small = tbl_n
 else
  big = tbl_n
  small = tbl_m
 end
 -- expand small
 for i = table.getn(small) + 1, table.getn(big) do
  small[i] = 0
 end

end

local function bit_or(m, n)
 local tbl_m = to_bits(m)
 local tbl_n = to_bits(n)
 expand(tbl_m, tbl_n)

 local tbl = {}
 local rslt = math.max(table.getn(tbl_m), table.getn(tbl_n))
 for i = 1, rslt do
  if(tbl_m[i]== 0 and tbl_n[i] == 0) then
   tbl[i] = 0
  else
   tbl[i] = 1
  end
 end
 
 return tbl_to_number(tbl)
end

local function bit_and(m, n)
 local tbl_m = to_bits(m)
 local tbl_n = to_bits(n)
 expand(tbl_m, tbl_n) 

 local tbl = {}
 local rslt = math.max(table.getn(tbl_m), table.getn(tbl_n))
 for i = 1, rslt do
  if(tbl_m[i]== 0 or tbl_n[i] == 0) then
   tbl[i] = 0
  else
   tbl[i] = 1
  end
 end

 return tbl_to_number(tbl)
end

local function bit_not(n)
 
 local tbl = to_bits(n)
 local size = math.max(table.getn(tbl), 32)
 for i = 1, size do
  if(tbl[i] == 1) then 
   tbl[i] = 0
  else
   tbl[i] = 1
  end
 end
 return tbl_to_number(tbl)
end

local function bit_xor(m, n)
 local tbl_m = to_bits(m)
 local tbl_n = to_bits(n)
 expand(tbl_m, tbl_n) 

 local tbl = {}
 local rslt = math.max(table.getn(tbl_m), table.getn(tbl_n))
 for i = 1, rslt do
  if(tbl_m[i] ~= tbl_n[i]) then
   tbl[i] = 1
  else
   tbl[i] = 0
  end
 end
 
 --table.foreach(tbl, print)

 return tbl_to_number(tbl)
end

local function bit_rshift(n, bits)
 check_int(n)
 
 local high_bit = 0
 if(n < 0) then
  -- negative
  n = bit_not(math.abs(n)) + 1
  high_bit = 2147483648 -- 0x80000000
 end

 for i=1, bits do
  n = n/2
  n = bit_or(math.floor(n), high_bit)
 end
 return math.floor(n)
end

-- logic rightshift assures zero filling shift
local function bit_logic_rshift(n, bits)
 check_int(n)
 if(n < 0) then
  -- negative
  n = bit_not(math.abs(n)) + 1
 end
 for i=1, bits do
  n = n/2
 end
 return math.floor(n)
end

local function bit_lshift(n, bits)
 check_int(n)
 
 if(n < 0) then
  -- negative
  n = bit_not(math.abs(n)) + 1
 end

 for i=1, bits do
  n = n*2
 end
 return bit_and(n, 4294967295) -- 0xFFFFFFFF
end

local function bit_xor2(m, n)
 local rhs = bit_or(bit_not(m), bit_not(n))
 local lhs = bit_or(m, n)
 local rslt = bit_and(lhs, rhs)
 return rslt
end

--------------------
-- bit lib interface

bit = {
 -- bit operations
 bnot = bit_not,
 band = bit_and,
 bor  = bit_or,
 bxor = bit_xor,
 brshift = bit_rshift,
 blshift = bit_lshift,
 bxor2 = bit_xor2,
 blogic_rshift = bit_logic_rshift,

 -- utility func
 tobits = to_bits,
 tonumb = tbl_to_number,
}

local math = math;
local table = table;
local string = string;

function bitor2(n1, n2)
  return bit_or(n1, n2)
end
function bitor3(n1, n2, n3)
  return bit_or(bit_or(n1, n2), n3)
end
function bitor4(n1, n2, n3, n4)
  return bit_or(bit_or(bit_or(n1, n2), n3), n4);
end

function bitxor2(n1, n2)
  return bit_xor(n1, n2)
end
function bitxor3(n1, n2, n3)
  return bit_xor(bit_xor(n1, n2), n3)
end
function bitxor4(n1, n2, n3, n4)
  return bit_xor(bit_xor(bit_xor(n1, n2), n3), n4);
end

function bitand2(n1, n2)
  return bit_and(n1, n2);
end

function bitlshift(n, bit)
  return bit_lshift(n, bit);
end

function bitrshift(n, bit)
  return bit_rshift(n, bit);
end


function Empty(str)
  return str == nil or str == '';
end

function empty(str) 
	if type(str) == 'string' then
		return Empty(str); 
	elseif type(str) == 'table' then
		return #str;
	end
	return 0;
end
function Push(t, v) table.insert(t, v); end
function Clear(t) 
  while (#t > 0) do
    table.remove(t, 0);
  end
end

function length(n)
	if (type(n) == 'string') then
		return string.len(n);
	elseif (type(n) == 'table') then
		return table.maxn(n);
	end
	return 0;
end

function Sort(t)
	table.sort(t);
end

function Erase(t, i)
	table.remove(t, i);
end

function Insert(t, i, n)
	table.insert(t, i, n);
end

function Join(t, p)
	return table.concat(t, p);
end

function Find(t, n)
	for k,v in pairs(t) do
		if (v == n) then
			return k;
		end
	end
	return -1;
end

function Trimmed(str)
  local from = str:match"^%s*()"
  return from > #str and "" or str:match(".*%S", from)
end

function Resize(str, n)
  local l = n - string.len(str);
  while (l > 0) do
    str = str .. " ";
  end
  return str;
end

function ifor(b, x, y) return returnor(b, x, y); end
function returnor(b, x, y)
    if (b) then 
        return x;
    end
    return y;
end

function Substring(str, n)
	local str = string.sub(str, 1, n);
	return str;
end

function StartsWith(str, s)
  if string.len(str) < string.len(s) then
    return false;
  end
  local sstr = string.sub(str, 1, string.len(s));
  return sstr == s;
end

function EndsWith(str, s)
	if (string.len(str) < string.len(s)) then
		return false;
	end
	local strr = string.sub(str, string.len(str) - string.len(s), string.len(s));
	return sstr == s;
end

function String(s)
	return tostring(s);
end


function Substring(str, n)
  local s = string.sub(str, 1, n);
  return s;
end

function Replaced(str, pat, rep)
  local s = string.gsub(str, pat, rep);
  return s;
end

function Split(str)
  if str == nil or str == '' or delimiter == nil then
    return nil
  end
  
  local result = {}
  for match in (str..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match)
  end
  return result
end

end
