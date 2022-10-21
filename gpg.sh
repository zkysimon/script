rm vanity_gpg
wget https://github.com/zkysimon/script/releases/download/0.3.3/vanity_gpg
chmod +x vanity_gpg
nohup ./vanity_gpg -c RSA4096 -j128 -u "mjj <mjj@abc.com>" -p "A{14,40}$|B{14,40}$|C{14,40}$|D{14,40}$|E{14,40}$|F{14,40}$|1{14,40}$|2{14,40}$|3{14,40}$|4{14,40}$|5{14,40}$|6{14,40}$|7{14,40}$|8{14,40}$|9{14,40}$|0{14,40}$|0123456789ABCDEF$|(?:0{4}|1{4}|2{4}|3{4}|4{4}|5{4}|6{4}|7{4}|8{4}|9{4}|A{4}|B{4}|C{4}|D{4}|E{4}|F{4}){4}$" &
