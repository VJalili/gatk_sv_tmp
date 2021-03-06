#!/bin/bash

# Performs QC on an RD metadata matrix generated by module 00

set -e

#Usage statement
usage(){
cat <<EOF

usage: RD_matrix_QC.sh [-h] [-d DISTANCE] MATRIX GENOME OUTFILE

Performs QC on an RD metadata matrix

Positional arguments:
  MATRIX   full path to matrix to be QCed
  GENOME   full path to genome file for evaluation (see BEDTools documentation)
  OUTFILE  full path to desired QC output file

Optional arguments:
  -h  HELP      Show this help message and exit
  -d  DISTANCE  Distance from q-terminus of each chromosome to evaluate (default: 1000000) 

EOF
}

#Parse arguments
DISTANCE=1000000
while getopts ":d:h" opt; do
  case "$opt" in
    h)
      usage
      exit 0
      ;;
    d)
      DISTANCE=${OPTARG}
      ;;
  esac
done
shift $(( ${OPTIND} - 1))
MATRIX=$1
GENOME=$2
OUTFILE=$3

#Check arguments
if ! [ -s ${MATRIX} ]; then
  echo -e "\nERROR: specified MATRIX file does not exist or is empty. Exiting."
  usage
  exit 1
fi
if ! [ -s ${GENOME} ]; then
  echo -e "\nERROR: specified GENOME file does not exist or is empty. Exiting."
  usage
  exit 1
fi
if [ ${DISTANCE} -lt 1 ]; then
  echo -e "\nERROR: DISTANCE must be an integer greater than zero. Exiting."
  usage
  exit 1
fi

#Write header for outfile
echo -e "#ID\tchromosome\tnonzero_bins_in_tail" > ${OUTFILE}

#Iterate over contigs & write results to outfile
while read contig end; do
  #Get start position of window to check
  start=$(( ${end} - ${DISTANCE} ))
  if [ ${start} -lt 1 ]; then
    start=1
  fi

  #Cut RD matrix tail to tmp space
  TMPMATRIX=`mktemp`
  tabix -h ${MATRIX} "${contig}:${start}-${end}" > ${TMPMATRIX}

  #Compute number of nonzero bins for all columns after 1-3
  Rscript -e "x <- read.table(\"${TMPMATRIX}\",sep=\"\\t\",header=T,comment.char=\"\");\
  x <- x[,-c(1:3)];\
  bins <- apply(x,2,function(vals){return(length(which(vals>0)))});\
  res <- data.frame(colnames(x),as.numeric(bins));\
  print(res)" | sed '1d' | awk -v OFS="\t" -v contig="${contig}" \
  '{ print $2, contig, $3 }'

  #Clean up
  rm ${TMPMATRIX}

done < <( fgrep -v "#" ${GENOME} ) | sort -k1,1 -k2,2V >> ${OUTFILE}


