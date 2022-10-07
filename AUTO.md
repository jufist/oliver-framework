ech2 "Opening location" genKey --init --ctrl l ech2 "Sending location $STRING" genKey --raw "Delay 5 String $STRING
Delay 2" ech2 "Sending Backspace" genKey BackSpace genKey Return genKey --raw Delay 2 genKey --ctrl a genKey Return
playKey
