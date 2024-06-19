package Simple_VPC

import (
"fmt"
"os"
"crypto/rand"
"io"
)

func main() {
	for i := 1; i <= 3; i++ {
		file, _ := os.Create(fmt.Sprintf("file%d.txt", i))
		defer file.Close()
		io.CopyN(file, rand.Reader, int64(100) * 1024 * 1024)
	}
}