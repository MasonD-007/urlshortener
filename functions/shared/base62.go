package function

import (
	"math"
)

const base62Chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

// EncodeBase62 converts an integer to a base62 string
func EncodeBase62(num int64) string {
	if num == 0 {
		return "0"
	}

	base := int64(len(base62Chars))
	encoded := ""

	for num > 0 {
		remainder := num % base
		encoded = string(base62Chars[remainder]) + encoded
		num = num / base
	}

	return encoded
}

// DecodeBase62 converts a base62 string back to an integer
func DecodeBase62(encoded string) (int64, error) {
	base := int64(len(base62Chars))
	var num int64 = 0

	for i, char := range encoded {
		power := len(encoded) - i - 1
		index := indexOf(byte(char))
		if index == -1 {
			return 0, nil // Invalid character
		}
		num += int64(index) * int64(math.Pow(float64(base), float64(power)))
	}

	return num, nil
}

// indexOf returns the index of a character in the base62 character set
func indexOf(char byte) int {
	for i := 0; i < len(base62Chars); i++ {
		if base62Chars[i] == char {
			return i
		}
	}
	return -1
}
