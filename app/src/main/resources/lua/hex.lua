-- module()/package.seeall 自 Lua 5.2 起已废弃。
-- 这里改为显式模块表，并保留同名全局，原有调用方式不受影响。
local hex = {}
_G.hex = hex

function hex.dump(v, delimiter, stx, etx)

   local dump = ""

   if delimiter == nil then delimiter = "" end

   dump = v:gsub( "(.)", function (c) return delimiter .. string.format( "%02X", c:byte(1) ) end )

   dump = dump:sub(1 + delimiter:len(), -1)

   if stx ~= nil then dump = stx .. dump end;
   if etx ~= nil then dump = dump .. etx end;

   return dump
end

function hex.smart_dump(v)
   v = v:gsub( "%c+", function (raw) return hex.dump(raw, "", "<", ">") end  );
   return v
end

function hex.pack(v)

   v = v:gsub( "%s+", "" )

   local pack = ""

   local table = {
   --  0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- 00
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- 10
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- 20
       0,  1,  2,  3,  4,  5,  6,  7,  8,  9, -1, -1, -1, -1, -1, -1, -- 30
      -1, 10, 11, 12, 13, 14, 15, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- 40
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- 50
      -1, 10, 11, 12, 13, 14, 15, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- 60
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- 70
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- 80
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- 90
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- A0
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- B0
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- C0
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- D0
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- E0
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -- F0
   }

   assert( (v:len() % 2) == 0, "Length '" .. v .. "' (" .. v:len() .. ") length is odd" );

   local first = -1;

   for i = 1, v:len() do
      local c = v:byte(i)
      assert( table[ c+1 ] > -1, "hex.pack(), non-hex char '" .. string.format("%c", c) .. "' at position " .. i );

      if first == -1 then
         first = table[ c+1 ] * 16;
      else
         pack = pack .. string.char( first + table[ c+1 ] );
         first = -1;
      end
   end

   return pack
end

function hex.smart_pack(v)
   local packed = v:gsub( "<(%x+)>", function (dump) return hex.pack(dump) end )
   return packed
end

return hex
