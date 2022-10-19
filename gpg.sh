rm vanity_gpg
wget https://github.com/zkysimon/script/releases/download/0.3.2/vanity_gpg
chmod +x vanity_gpg
nohup ./vanity_gpg -c RSA4096 -j128 -u "mjj <mjj@abc.com>" -p "A{12,40}$|B{12,40}$|C{12,40}$|D{12,40}$|E{12,40}$|F{12,40}$|1{12,40}$|2{12,40}$|3{12,40}$|4{12,40}$|5{12,40}$|6{12,40}$|7{12,40}$|8{12,40}$|9{12,40}$|0{12,40}$|0123456789ABCDEF$" &
