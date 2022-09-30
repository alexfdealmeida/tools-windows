cls
cd "D:\bin\unixutil\iconv"
"D:\bin\unixutil\iconv\iconv.exe" --binary -c -f UCS-2LE -t ISO-8859-1 "teste.sql" > "teste2.sql"
del "teste.sql"
rename "teste2.sql" "teste.sql"
pause