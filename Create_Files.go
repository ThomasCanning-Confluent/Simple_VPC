package Simple_VPC

import (
"fmt"
"os"
"crypto/rand"
"io"
)

//This GO program creates 3 files with random data of 100MB each
func main() {
	for i := 1; i <= 3; i++ {
		//This line creates a file with the name filei.txt where i takes the values 1, 2, then 3
		file, _ := os.Create(fmt.Sprintf("file%d.txt", i))
		defer file.Close()
		//This line writes 100MB of random data to the file
		io.CopyN(file, rand.Reader, int64(100) * 1024 * 1024)
	}
}