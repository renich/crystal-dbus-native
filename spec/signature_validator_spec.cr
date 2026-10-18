require "./spec_helper"

# Verifies [FUNC-002] / [TECH-002], [TECH-005]
describe Crystal::Dbus::Native::SignatureValidator do
  describe ".validate" do
    it "validates basic types and variant" do
      %w[y b n q i u x t d s o g v h].each do |type_code|
        Crystal::Dbus::Native::SignatureValidator.validate(type_code).should be_nil
      end
    end

    it "raises on invalid type code" do
      expect_raises(Crystal::Dbus::Native::SignatureError, "Invalid type code") do
        Crystal::Dbus::Native::SignatureValidator.validate("z")
      end
    end

    it "validates arrays and dictionary entries" do
      Crystal::Dbus::Native::SignatureValidator.validate("ai").should be_nil
      Crystal::Dbus::Native::SignatureValidator.validate("a{ss}").should be_nil
    end

    it "rejects container types and variants as dictionary keys" do
      expect_raises(Crystal::Dbus::Native::SignatureError, "Dict key must be a basic type") do
        Crystal::Dbus::Native::SignatureValidator.validate("a{vs}")
      end
    end

    it "rejects dictionary entries with more than one value type" do
      expect_raises(Crystal::Dbus::Native::SignatureError, "Unclosed dict or too many elements") do
        Crystal::Dbus::Native::SignatureValidator.validate("a{svi}")
      end
    end

    it "validates structs" do
      Crystal::Dbus::Native::SignatureValidator.validate("(is)").should be_nil
      Crystal::Dbus::Native::SignatureValidator.validate("(i(ss))").should be_nil
    end

    it "rejects empty structs" do
      expect_raises(Crystal::Dbus::Native::SignatureError, "Empty struct") do
        Crystal::Dbus::Native::SignatureValidator.validate("()")
      end
    end

    it "raises on unbalanced struct" do
      expect_raises(Crystal::Dbus::Native::SignatureError, "Unclosed struct") do
        Crystal::Dbus::Native::SignatureValidator.validate("(i")
      end
      expect_raises(Crystal::Dbus::Native::SignatureError, "Invalid type code") do
        Crystal::Dbus::Native::SignatureValidator.validate("i)")
      end
      expect_raises(Crystal::Dbus::Native::SignatureError, "Unclosed struct") do
        Crystal::Dbus::Native::SignatureValidator.validate("((i)")
      end
    end

    it "allows 32 nested arrays combined with 32 nested structs and rejects > MAX_DEPTH" do
      valid_combined = ("a" * 32) + ("(" * 32) + "i" + (")" * 32)
      Crystal::Dbus::Native::SignatureValidator.validate(valid_combined).should be_nil

      deep_struct = ("(" * 33) + "i" + (")" * 33)
      expect_raises(Crystal::Dbus::Native::SignatureError, "Depth exceeded") do
        Crystal::Dbus::Native::SignatureValidator.validate(deep_struct)
      end

      deep_array = ("a" * 33) + "i"
      expect_raises(Crystal::Dbus::Native::SignatureError, "Depth exceeded") do
        Crystal::Dbus::Native::SignatureValidator.validate(deep_array)
      end
    end

    it "raises when signature length exceeds MAX_LENGTH" do
      sig = "i" * 256
      expect_raises(Crystal::Dbus::Native::SignatureError, "too long") do
        Crystal::Dbus::Native::SignatureValidator.validate(sig)
      end
    end

    it "raises on mismatched brackets like (}" do
      expect_raises(Crystal::Dbus::Native::SignatureError, "Invalid type code") do
        Crystal::Dbus::Native::SignatureValidator.validate("(}")
      end
      expect_raises(Crystal::Dbus::Native::SignatureError, "Dict entry must be inside array") do
        Crystal::Dbus::Native::SignatureValidator.validate("{)")
      end
    end

    it "raises on unclosed brackets for generic cases" do
      expect_raises(Crystal::Dbus::Native::SignatureError, "Unclosed struct") do
        Crystal::Dbus::Native::SignatureValidator.validate("(((i))")
      end
      expect_raises(Crystal::Dbus::Native::SignatureError, "Unexpected end of signature") do
        Crystal::Dbus::Native::SignatureValidator.validate("a{i")
      end
    end
  end
end
