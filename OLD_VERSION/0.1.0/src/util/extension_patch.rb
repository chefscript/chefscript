#################################################################################
# Extension Patch
#################################################################################
class Object
  def to_b
    compare_value = self.class == String ? self.downcase : self
    case compare_value
      when "yes", "true", "ok", "1", :yes, :true, :ok, true, 1
        true
      else
        false
    end
  end
end
