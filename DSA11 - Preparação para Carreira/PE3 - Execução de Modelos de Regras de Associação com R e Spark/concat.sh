rm wiltshirepolice.csv
touch wiltshirepolice.csv
FILES="/Users/dmpm/Dropbox/DSA/ProjetosEspeciais/Projeto3/files/*/*.csv"
OUTPUT="wiltshirepolice.csv"
i=0
for filename in $FILES; do 
if [ "$filename"  != "$OUTPUT" ] ;      
 then 
   if [[ $i -eq 0 ]] ; then 
      head -1  $filename >   $OUTPUT 
   fi
   tail -n +2  $filename >>  $OUTPUT 
   i=$(( $i + 1 ))                        
 fi
done