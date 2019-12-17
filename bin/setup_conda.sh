#!/bin/bash

sys="$(uname)" # Linux for Linux or Darwin for MacOS
echo "Current OS system: $sys"

flag=0
### check grep, sed and wget availability
echo "-------------------------------------"
echo "Checking .bash_profile/.bashrc, grep, sed/gsed and wget availability..."
grepprog='grep'
sedprog='sed'
wgetprog='wget'
bashFile='.bashrc'
if [ "$sys" == "Darwin" ]; then
    sedprog='gsed'
	grepprog='ggrep'
	shell=$(echo $SHELL)
	if [ $shell == "/bin/zsh" ]; then
    	bashFile='.zshrc'
	else
		bashFile='.bash_profile'
	fi
fi

# NOTE: install only available for Linux!
if [ -z "$(which $sedprog)" ]; then
    if [ "$sys" == "Darwin" ]; then
        echo "$sedprog not found. Please install it first (e.g. using brew)!"
        flag=1
    fi
	conda install -c conda-forge sed
fi

if [ -z "$(which $grepprog)" ]; then
    if [ "$sys" == "Darwin" ]; then
        echo "$grepprog not found. Please install it first (e.g. using brew)!"
        flag=1
    fi
	conda install -c bioconda grep
fi

if [ -z "$(which $wgetprog)" ]; then
    if [ "$sys" == "Darwin" ]; then
        echo "$wgetprog not found. Please install it first (e.g. using brew)!"
        flag=1
    fi
	conda install -c anaconda wget
fi

if ! [ -f ~/$bashFile ]; then
    touch ~/$bashFile
fi
if [ "$flag" == 1 ]; then exit 1; fi
echo "done!"

### check dependencies
echo "-------------------------------------"
echo "Installing dependencies..."

if [ -z "$(which R)" ]; then
    echo "R"
    conda install -y r
fi

if [[ -z $(conda list | grep "pkg-config ") ]]; then
    echo "pkg-config"
    conda install -y pkg-config
fi

if [[ -z $(conda list | grep "perl-bioperl ") ]]; then
    echo "perl-bioperl"
    conda install -y -c bioconda perl-bioperl
    conda install -y -c bioconda perl-bioperl-core
    conda install -y -c bioconda perl-bioperl-run
fi

dependencies=(
  blastp # blast
  genewise # wise2
  hmmsearch # hmmer (for both hmmsearch and hmmbuild)
  clustalw
  mafft # for linsi
  muscle
)

for i in "${dependencies[@]}"; do
  if [ -z "$(which $i)" ]; then
    echo $i
    tool=$i
    if [ "$tool" = "blastp" ]; then
      conda install -y -c bioconda blast
    elif [ "$tool" = "hmmsearch" ]; then
      conda install -y -c bioconda hmmer
    elif [ "$tool" = "genewise" ]; then
      conda install -y -c bioconda wise2
      wisePath=$(which "genewise")
      if [ -z "$(grep WISECONFIGDIR=$wisePath ~/$bashFile)" ]; then
          echo "export WISECONFIGDIR=${wisePath}" >> ~/$bashFile
      fi
    else
      conda install -y -c bioconda $i
    fi
  fi
done

for i in "${dependencies[@]}"; do
  if [ -z "$(which $i)" ]; then
    echo "$i not found. Please install it to use HaMStR!"
    flag=1
  fi
done
if [ "$flag" == 1 ]; then exit 1; fi

perlModules=(
  DBI
  DB_File
  File::Copy
  File::Path
  File::Basename
  File::Which
  List::Util
  Parallel::ForkManager
  POSIX
  XML::SAX
  XML::NamespaceSupport
  XML::Parser
  Getopt::Long
  IO::Handle
  IPC::Run
  Statistics::R
  Term::Cap
  Time::HiRes
  Bio::AlignIO
  Bio::Align::ProteinStatistics
  Bio::DB::Taxonomy
  Bio::SearchIO
  Bio::SearchIO::blastxml
  Bio::Search::Hit::BlastHit
  Bio::Seq
  Bio::SeqIO
  Bio::SeqUtils
  Bio::Tree::Tree
  Bio::Tools::Run::StandAloneBlast
)

for i in "${perlModules[@]}"; do
  msg=$((perldoc -l $i) 2>&1)
  if [[ "$(echo $msg)" == *"No documentation"* ]]; then
    cpanm ${i} --quiet --force
  fi
done

echo "done!"

### prepare folders
echo "-------------------------------------"
echo "Preparing folders..."
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR/..
CURRENT=$(pwd)

# create required folders
folders=(
  blast_dir
  core_orthologs
  genome_dir
  weight_dir
  taxonomy
  output
  tmp
  "bin/aligner"
)

for i in "${folders[@]}"; do
  echo "$i"
  if [ ! -d $i ]; then mkdir $i; fi
done
echo "done!"

### download tools
echo "-------------------------------------"
echo "Downloading and installing annotation tools/databases:"

fasta36="yes"
if [ -z "$(which fasta36)" ]; then
  fasta36="no"
  fasta36v="fasta-36.3.8h"
  if ! [ -f "bin/aligner/bin/fasta36" ]; then
	  echo "fasta-36"
	  wget "http://faculty.virginia.edu/wrpearson/fasta/fasta36/${fasta36v}.tar.gz"
	  tar xfv $fasta36v.tar.gz
	  rm "${fasta36v}.tar.gz"
	  mv $fasta36v/* bin/aligner/
	  rm -rf $fasta36v
	  cd "bin/aligner/src"
	  if [ $sys=="Linux" ]; then
	    make -f ../make/Makefile.linux64_sse2 all
	  elif [ $sys=="Darwin" ]; then
	    make -f ../make/Makefile.os_x86_64 all
	  fi
  fi
  if [ -z "$(grep PATH=$CURRENT/bin/aligner/bin ~/$bashFile)" ]; then
	  echo "export PATH=$CURRENT/bin/aligner/bin:\$PATH" >> ~/$bashFile
  fi
fi
cd $CURRENT
if [ -z "$(which fasta36)" ]; then
	if ! [ -f "$CURRENT/bin/aligner/bin/fasta36" ]; then
		echo "fasta36 tool could not be found in $CURRENT/bin/aligner/. Please check again!"
		exit
	fi
fi

cd "taxonomy"
if ! [ -f "nodes" ]; then
  wget "ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz"
  tar xfv taxdump.tar.gz
  rm taxdump.tar.gz
  echo "Taxonomy database indexing. It can take a while, please wait..."
  perl $CURRENT/bin/indexTaxonomy.pl $CURRENT/taxonomy
  rm *.dmp
  rm gc.prt
  rm readme.txt
fi
cd $CURRENT
if ! [ -f "$CURRENT/taxonomy/nodes" ]; then
	echo "Error while indexing NCBI taxonomy database! Please check $CURRENT/taxonomy/ folder and run this setup again!"
	exit
fi

cd "bin"
if [ -z "$(which greedyFAS)" ]; then
    echo "FAS"
    conda install -y -c BIONF fas
    if [ -z "$(which annoFAS)" ]; then
        echo "Installation of FAS failed! Please try again!"
        exit
    else
        annoFAS --fasta test.fa --path $CURRENT --name q --prepare 1 --annoPath $CURRENT/bin/fas
    fi
else
    fasPath="$(pip show greedyFAS | grep Location | sed 's/Location: //')"
    annoFile="$fasPath/greedyFAS/annoFAS.pl"
    tmp="$(grep "my \$config" $annoFile | sed 's/my \$config = //' | sed 's/;//')"
    if [ $tmp == "1" ]; then
        annoPath="$(grep "my \$annotationPath" $annoFile | sed 's/my \$annotationPath = "//' | sed 's/";//')"
        echo $annoPath
        if ! [ -f "$annoPath/Pfam/Pfam-hmms/Pfam-A.hmm" ]; then
            annoFAS --fasta test.fa --path $CURRENT --name q --prepare 1 --annoPath $annoPath
        fi
    else
        annoFAS --fasta test.fa --path $CURRENT --name q --prepare 1 --annoPath $CURRENT/bin/fas
    fi
fi
cd $CURRENT
echo "done!"

### download data
echo "-------------------------------------"
echo "Getting pre-calculated data"

if ! [ "$(ls -A $CURRENT/genome_dir)" ]; then
	echo "Processing $CURRENT ..."
	if [ ! -f $CURRENT/data_HaMStR.tar ]; then
		echo "Downloading data from https://applbio.biologie.uni-frankfurt.de/download/hamstr_qfo/data_HaMStR.tar"
		wget --no-check-certificate https://applbio.biologie.uni-frankfurt.de/download/hamstr_qfo/data_HaMStR.tar
	else
		CHECKSUM=$(cksum data_HaMStR.tar)
		echo "Checksum: $CHECKSUM"
		if ! [ "$CHECKSUM" == "4100986910 5840435200 data_HaMStR.tar" ]; then
    		  rm $CURRENT/data_HaMStR.tar
    		  echo "Downloading data from https://applbio.biologie.uni-frankfurt.de/download/hamstr_qfo/data_HaMStR.tar"
      		  wget --no-check-certificate https://applbio.biologie.uni-frankfurt.de/download/hamstr_qfo/data_HaMStR.tar
    	fi
    fi

	if [ ! -f $CURRENT/data_HaMStR.tar ]; then
	  echo "File data_HaMStR.tar not found! Please try to download again from"
	  echo "https://applbio.biologie.uni-frankfurt.de/download/hamstr_qfo/data_HaMStR.tar"
	  exit
	fi

	CHECKSUM=$(cksum data_HaMStR.tar)
	if [ "$CHECKSUM" == "4100986910 5840435200 data_HaMStR.tar" ]; then
	  echo "Extracting archive data_HaMStR.tar"
	  tar xfv $CURRENT/data_HaMStR.tar
	  rm $CURRENT/data_HaMStR.tar
	  echo "Archive data_HaMStR.tar extracted into $CURRENT"
	  if [ ! -d $CURRENT/data_HaMStR ]; then
		echo "Directory $CURRENT/data_HaMStR not found!"
	  else
		printf "\nMoving gene sets ...\n--------------------\n"
		rsync -rva data_HaMStR/genome_dir/* $CURRENT/genome_dir
		printf "\nMoving blast databases ...\n--------------------------\n"
		rsync -rva data_HaMStR/blast_dir/* $CURRENT/blast_dir
		printf "\nMoving annotations ...\n----------------------\n"
		rsync -rva data_HaMStR/weight_dir/* $CURRENT/weight_dir
		printf "\nRemoving duplicated data. Please wait.\n------------------------------------\n"
		rm -rf $CURRENT/data_HaMStR
		printf "\nDone! Data should be in place to run HaMStR.\n"
	  fi
	else
	  echo "Something went wrong with the download. Checksum does not match."
	  echo "Please try to download again from"
	  echo "https://applbio.biologie.uni-frankfurt.de/download/hamstr_qfo/data_HaMStR.tar"
	  echo "Please put it into $CURRENT folder and run this setup again!"
	  exit
	fi
fi

### add paths to bash profile file
echo "-------------------------------------"
echo "Adding paths to ~/$bashFile"

if [ -z "$(grep PATH=$CURRENT/bin:\$PATH ~/$bashFile)" ]; then
	echo "export PATH=$CURRENT/bin:\$PATH" >> ~/$bashFile
fi

wisePath=$(which "genewise")
if [ -z "$(grep WISECONFIGDIR=$wisePath ~/$bashFile)" ]; then
    echo "export WISECONFIGDIR=${wisePath}" >> ~/$bashFile
fi
echo "done!"

### adapt paths in hamstr scripts
echo "-------------------------------------"
echo "Adapting paths in hamstr scripts"
# update the sed and grep commands
$sedprog -i -e "s/\(my \$sedprog = '\).*/\1$sedprog';/" $CURRENT/bin/hamstr.pl;
$sedprog -i -e "s/\(my \$grepprog = '\).*/\1$grepprog';/" $CURRENT/bin/hamstr.pl;
$sedprog -i -e "s/\(my \$sedprog = '\).*/\1$sedprog';/" $CURRENT/bin/oneSeq.pl;
$sedprog -i -e "s/\(my \$grepprog = '\).*/\1$grepprog';/" $CURRENT/bin/oneSeq.pl;

# localize the perl installation
path2perl=`which perl`
echo "path to perl: $path2perl"
$sedprog -i -e "s|\#\!.*|\#\!$path2perl|g" $CURRENT/bin/hamstr.pl;
$sedprog -i -e "s|\#\!.*|\#\!$path2perl|g" $CURRENT/bin/nentferner.pl;
$sedprog -i -e "s|\#\!.*|\#\!$path2perl|g" $CURRENT/bin/translate.pl;
$sedprog -i -e "s|\#\!.*|\#\!$path2perl|g" $CURRENT/bin/oneSeq.pl;

# get lib path
path2dir=$CURRENT
echo "path to lib: $path2dir/lib"
$sedprog -i -e "s|use lib.*lib\(.*\)|use lib '$path2dir/lib\1|" $CURRENT/bin/hamstr.pl
$sedprog -i -e "s|use lib.*|use lib '$path2dir/lib';|" $CURRENT/bin/nentferner.pl
$sedprog -i -e "s|use lib.*|use lib '$path2dir/lib';|g" $CURRENT/bin/translate.pl
$sedprog -i -e "s|use lib.*|use lib '$path2dir/lib';|g" $CURRENT/bin/oneSeq.pl

# paths to core_ortholog and blast_dir
echo "default path to blast_dir and core_orthologs: $path2dir"
$sedprog -i -e "s|\(my \$path = \).*|\1 '$path2dir';|g" $CURRENT/bin/hamstr.pl

###### CAN REMOVE THIS VAR $check_genewise in hamstr.pl ##########################
$sedprog -i -e 's/$check_genewise = [0,1];/$check_genewise = 1;/' $CURRENT/bin/hamstr.pl;
###############################################

### final check
echo "-------------------------------------"
echo "Final check..."
flag=0

echo "Conda packages"
condaPkgs=(
  perl-bioperl
  perl-bioperl-core
  blast
  hmmer
  wise2
  clustalw
  mafft
  muscle
)
for i in "${condaPkgs[@]}"; do
    if [[ -z $(conda list | grep "$i ") ]]; then
        echo "$i could not be installed"
        flag=1
    fi
done
echo "done!"

echo "Perl modules"
for i in "${perlModules[@]}"; do
  msg=$((perl -e "use $i") 2>&1)
  if ! [[ -z ${msg} ]]; then
    echo "$i could not be installed"
    flag=1
  fi
done
echo "done!"

echo "Environment paths"
envPaths=(
  # "ONESEQDIR=$CURRENT"
  WISECONFIGDIR
)
for i in "${envPaths[@]}"; do
    if [ -z "$(grep $i ~/$bashFile)" ]; then
        echo "$i was not added into ~/$bashFile"
        flag=1
    fi
done
if [ "$fasta36" == "no" ]; then
    if [ -z "$(grep PATH=$CURRENT/bin/aligner/bin ~/$bashFile)" ]; then
        echo "$CURRENT/bin/aligner/bin was not added into ~/$bashFile"
        flag=1
    fi
fi
if [ -z "$(grep PATH=$CURRENT/bin:\$PATH ~/$bashFile)" ]; then
	echo "$CURRENT/bin was not added into ~/$bashFile"
fi

echo "done!"

if [ "$flag" == 1 ]; then
    echo "Some tools were not installed correctly or paths were not added into ~/$bashFile. Please run this setup again to try one more time!"
    exit
else
    echo "Generating symbolic link hamstr -> hamstr.pl"
    ln -s -f $CURRENT/bin/hamstr.pl $CURRENT/bin/hamstr
    echo "Sourcing bash profile file"
    source ~/$bashFile
    echo "All tests succeeded, HaMStR should be ready to run";
    $sedprog -i -e 's/my $configure = .*/my $configure = 1;/' $CURRENT/bin/hamstr.pl;
    $sedprog -i -e 's/my $configure = .*/my $configure = 1;/' $CURRENT/bin/oneSeq.pl;
    echo "Restart terminal and test your HaMStR with:"
    echo "perl bin/oneSeq.pl -seqFile=infile.fa -seqid=P83876 -refspec=HUMAN@9606@1 -minDist=genus -maxDist=kingdom -coreOrth=5 -cleanup -global"
    echo "or"
    echo "perl bin/oneSeq.pl -h"
    echo "for more details."
fi
exit 1
