#!/home/iNut/local/bin/zsh

# set parameters
dir="/home/iNut/project/sra_qualitycheck"
log="/home/iNut/project/sra_qualitycheck/log/listupdate_`date %y%m%d%H%M%S`.log"

# get latest submission record
echo "updating submission list..."
lftp -c "open ftp.ncbi.nlm.nih.gov/sra/reports/Metadata && pget -n 8 SRA_Accessions.tab -o ${dir}/accessions.tab"
lftp -c "open ftp.ncbi.nlm.nih.gov/sra/reports/Metadata && pget -n 8 SRA_Run_Members.tab -o ${dir}/run_members.tab"

if [ -e ${dir}/accessions.tab && -s ${dir}/accessions.tab ] ; then
	echo "updated accession list."
else
	echo "failed updating accession list."
	echo "failed updating accession list: file couldn't be downloaded or empty" > ${log}
	exit
fi

if [ -e ${dir}/run_members.tab && -s ${dir}/run_members.tab ] ; then
	echo "updated run_members list."
else
	echo "failed updating run_members list."
	echo "failed updating run_members list: file couldn't be downloaded or empty" > ${log}
	exit
fi

# make a list of available submission id list
echo "processing submission id..."
cut -f 1,3 ${dir}/accessions.tab | egrep '^(S|E|D)' | egrep 'live' | cut -f 1 > ${dir}/available_subid.list

# make a list of available paper-published SRA data
echo "processing paper-published submission id..."
wget -O ${dir}/publication.json "http://sra.dbcls.jp/cgi-bin/publication2.php"


