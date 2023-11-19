------------------------------------
------     Lua大数模块 by.niren      ------
------     2021.10.01 Gamelua+     ------
------------------------------------



local BigDecimal=luajava.bindClass("java.math.BigDecimal")
local MathContext=luajava.bindClass("java.math.MathContext")

local _M={}
_M.Precision=100
local mt={
  __add=function(a,b)--加
    return a.value.add(b.value,MathContext(_M.Precision))
  end,
  __sub=function(a,b)--减
    return a.value.subtract(b.value,MathContext(_M.Precision))
  end,
  __mul=function(a,b)--乘
    return a.value.multiply(b.value,MathContext(_M.Precision))
  end,
  __div=function(a,b)--除
    return a.value.divide(b.value,MathContext(_M.Precision))
  end,
  __idiv=function(a,b)--除
    return a.value.divideToIntegralValue(b.value,MathContext(_M.Precision))
  end,
  __pow=function(a,b)--乘方
    return a.value.pow(b,MathContext(_M.Precision))
  end,
  __mod=function(a,b)--取余数
    return a.value.remainder(b,MathContext(_M.Precision))
  end,
  __unm=function(a)--取负
    return a.value.negate()
  end,
  __tostring=function(a)
    return tostring(a.value)
  end
}

_M.new=function(b)
  local self={value=BigDecimal(b)}--用表的value保存值
  setmetatable(self,mt)--设置元方法实现运算符重载
  return self
end


--[[
调用方法
num1=big.new("64646466464646646464646460000055")
num2=big.new("6464664646466464646464664646")
print(num1*num2)
]]



return _M