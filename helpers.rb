class String
 def escape
   self.dump[1..-2]
 end

 def unescape
   eval %Q{"#{self}"}
 end
end
