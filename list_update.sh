#!/home/iNut/local/bin/zsh

# set parameters
dir="/home/iNut/project/sra_qualitycheck"
log="/home/iNut/project/sra_qualitycheck/log/listupdate_`date +%y%m%d%H%M%S`.log"
touch ${log}

# get latest submission record
echo "updating submission list..."
lftp -c "open ftp.ncbi.nlm.nih.gov/sra/reports/Metadata && pget -n 8 SRA_Accessions.tab -o ${dir}/accessions.tab"
lftp -c "open ftp.ncbi.nlm.nih.gov/sra/reports/Metadata && pget -n 8 SRA_Run_Members.tab -o ${dir}/run_members.tab"

if [ -e ${dir}/accessions.tab ] && [ -s ${dir}/accessions.tab ] ; then
	echo "successfully updated accession list."
	echo "successfully updated accession list." >> ${log}
else
	echo "failed to update accession list."
	echo "failed to update accession list: file couldn't be downloaded or empty" >> ${log}
	exit
fi

if [ -e ${dir}/run_members.tab ] && [ -s ${dir}/run_members.tab ] ; then
	echo "successfully updated run_members list."
	echo "successfully updated run_members list." >> ${log}
else
	echo "failed to update run_members list."
	echo "failed to update run_members list: file couldn't be downloaded or empty" >> ${log}
	exit
fi

# make a list of available submission id list
echo "processing run id list..."
cut -f 1,8 ${dir}/run_members.tab | egrep 'live' | cut -f 1 | sort -u > ${dir}/allavailable_runid.list

# make a list of available paper-published SRA data
echo "updating paper-published item information..."
wget -O ${dir}/publication.json "http://sra.dbcls.jp/cgi-bin/publication2.php"

if [ -e ${dir}/publication.json ] && [ -s ${dir}/publication.json ] ; then
	echo "successfully updated paper-published submission id list."
	echo "successfully updated paper-published submission id list." >> ${log}
else
	echo "failed to update paper-published submission id list."
	echo "failed to update paper-published submission id list: file couldn't downloaded or empty" >> ${log}
	exit
fi

# extract id list from json format file, convert subid to runid
echo "processing paper-published runid..."
ruby ${dir}/parse_sras_json.rb --all-subid > ${dir}/paperpublished_subid.list
cut -f 1,2,3 ${dir}/accessions.tab | egrep 'live' | egrep '(S|E|D)RR' > ${dir}/paperpublished_middle.list

cat ${dir}/paperpublished_subid.list | while read f ; do ;
	egrep ${f} ${dir}/paperpublished_middle.list | cut -f 1
done > ${dir}/paperpublished_runid.list

# cleaning directory
echo "cleaning directory..."
mv ${dir}/accessions.tab ${dir}/tmp/accessions_`date +%Y%m%d%H%M%S`.tab
mv ${dir}/run_members.tab ${dir}/tmp/run_members_`date +%Y%m%d%H%M%S`.tab
rm -f ${dir}/publication.json
rm -f ${dir}/paperpublished_subid.list
rm -f ${dir}/paperpublished_middle.list

echo "process completed."
