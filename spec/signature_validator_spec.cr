require "./spec_helper"

describe Crystal::Dbus::Native::SignatureValidator do
  describe ".validate" do
    it "validates basic types" do
      ["y", "b", "n", "q", "i", "u", "x", "t", "d", "s", "o", "g", "v", "h"].each do |type|
        Crystal::Dbus::Native::SignatureValidator.validate(type).should be_nil
      end
    end

    it "raises on invalid type code" do
      expect_raises(Crystal::Dbus::Native::SignatureError, "Invalid type code") do
        Crystal::Dbus::Native::SignatureValidator.validate("z")
      end
    end

    it "validates arrays" do
      Crystal::Dbus::Native::SignatureValidator.validate("ai").should be_nil
      Crystal::Dbus::Native::SignatureValidator.validate("a{ss}").should be_nil
    end

    it "validates structs" do
      Crystal::Dbus::Native::SignatureValidator.validate("(is)").should be_nil
      Crystal::Dbus::Native::SignatureValidator.validate("(i(ss))").should be_nil
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

    it "raises when depth exceeds MAX_DEPTH" do
      sig = "(" * 33 + "i" + ")" * 33
      expect_raises(Crystal::Dbus::Native::SignatureError, "Depth exceeded") do
        Crystal::Dbus::Native::SignatureValidator.validate(sig)
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
