#!/bin/bash
echo $@
echo $1
options=`getopt -o '' -l StudyFolder:,Subject:,aromaexec:,repetitiontime:,motion::,prefix::,task:: -n 'fnl_ica_aroma_wrapper.sh' -- $@`
echo $options
eval set -- "$options"
echo $1
function display_help() {
	cat <<USAGE 
	Usage: `basename $0` <INPUTS> [OPTIONS]
	wrapper script to run ica aroma on an hcp subject for given fMRI data within Fair HCP folder structure

	REQUIRED:
	--path=<SUBJECT DIRECTORY>            subject directory as in Fair HCP format, including subject ID if hcponeclick
	--aromaexec=<AROMA EXECUTABLE>              path to the ica aroma python executable
	--repetitiontime=<TR>                       repetition time for fMRI scan
	--motion=<motion file>                      text/separated values/par file of motion regressors, check AROMA docs for available formats
	--tasklist=<fMRIname>[,fMRIname,...]        name[s] of rest/task folders (comma delimited)
	OPTIONAL:
	--prefix=<folder/file prefix>               prefix for output directory/data.  Can include additional output subdirectory, e.g. SUBJECTDIR/ICA/ica_aroma_(fMRIname)
	--noiseopt=<option>                         noise removal strategy:  aggr, nonaggr, or both (defaults to aggr, check AROMA docs for more details)
USAGE
	exit $1
}

#echo "RUNNING: ${BASH_SOURCE[0]}"
#if [ $( cd "$( dirname "${BASH_SOURCE[0]}")" && git rev-parse --is-inside-work-tree ) ]; then
#	echo "current git branch: $( cd "$( dirname "${BASH_SOURCE[0]}" )" && git rev-parse --abbrev-ref HEAD )"
#	echo "current git commit: $( cd "$( dirname "${BASH_SOURCE[0]}" )" && git rev-parse --short HEAD )"
#fi
echo "$options"
while true; do
	case "$1" in
		--StudyFolder)
			if [ -d "$2" ]; then
				StudyFolder="$2"
                echo $StudyFolder; shift 2
			else
				echo "SUBJECT DIRECTORY NOT AVAILABLE!: \"$2\""
				echo "EXITING..."
				exit 1
			fi
			;;
		--Subject)
			SubjectID="$2"
			shift 2
			;;
		--aromaexec)
			if [ -x "$2" ]; then
				AROMAEXEC="$2"; shift 2
			else
				echo "NOT AN EXECUTABLE FILE: \"$2\""
				exit 1
			fi
			;;
		--repetitiontime)
			if [[ ! $2 =~ '^[0-9]+([.][0-9]+)?$' ]]; then
				TR=$2; shift 2
			else
				echo "GIVEN TR IS NOT A DECIMAL NUMBER. EXITING..."
				exit 1
			fi
			;;
		--prefix)
			PREFIX="$2"; shift 2
			;;
		--noiseopt)
			NOISE_OPT=$2; shift 2
            ;;
		--task)
			TASKLIST=$2; shift 2
			;;
		--) shift ; break ;;
		*) echo "Unexpected argument while parsing args!"; display_help 1 ;;
	esac
done

# set default options
if [ -z $NOISE_OPT ]; then NOISE_OPT="aggr"; fi
if [ -z $PREFIX ]; then 
	PREFIX=ica_ # default
elif [ ! "$( dirname $PREFIX )" = "." ]; then
	# detect subdirectory in prefix
	SUBDIRECTORY="$( dirname $PREFIX )"
	if [ ! "$( basename $PREFIX )" = "." ]; then
		PREFIX="$( basename $PREFIX )"
	else
		PREFIX=""
	fi
fi
SUBJECTDIR="$StudyFolder"/"$SubjectID"

echo "running ica-aroma on $SUBJECTDIR"
echo "ica-aroma version: $( cd "$( dirname "$AROMAEXEC" )" && git describe --tags)"
pushd "$SUBJECTDIR" > /dev/null || { echo "can't access subject directory: $SUBJECTDIR  Exiting..."; exit 1; }

if [ -z ${TASKLIST} ]; then
    TASKLIST=`ls -d *fMRI*`
    echo Performing ICA_AROMA on: $TASKLIST
else
    echo Performing ICA_AROMA on: $TASKLIST
fi

#Delete previous runs if they exist
if [ -d ICA_AROMA ]; then
    rm -rf ICA_AROMA
fi

# Source the environment script
EnvironmentScript=${SUBJECTDIR}/Scripts/ProtocolSettings_copy.sh
source ${EnvironmentScript}

for NameOffMRI in $TASKLIST; do
    TR=$(bc -l <<< "scale=4;$(fslhd $SUBJECTDIR/MNINonLinear/Results/${NameOffMRI}/${NameOffMRI}.nii.gz | grep pixdim4 | gawk '{print $2}')/1000")
    # run ica-aroma on next fMRI in queue
	mkdir -p ICA_AROMA/${NameOffMRI} 2> /dev/null
    MOTIONFILE_12="$SUBJECTDIR"/MNINonLinear/Results/${NameOffMRI}/Movement_Regressors_FNL_preproc_v2.txt
    # The motion file for ica requires only the first 6 movement regressors. The other 6 must be removed 
    MOTIONFILE_6="$SUBJECTDIR"/MNINonLinear/Results/${NameOffMRI}/Movement_Regressors_FNL_preproc_v2_ICA.txt
    :> ${MOTIONFILE_6}
    cat $MOTIONFILE_12 | awk '{print $1 " " $2 " " $3 " " $4 " " $5 " " $6}' >> ${MOTIONFILE_6}
	${AROMAEXEC} -i "$SUBJECTDIR"/MNINonLinear/Results/${NameOffMRI}/${NameOffMRI}.nii.gz \
		-mc "${MOTIONFILE_6}" \
		-den ${NOISE_OPT} \
		-tr $TR \
		-o "$SUBJECTDIR"/ICA_AROMA/${NameOffMRI}

	# create symlinks on fMRI data.
    # remove previous runs if the exist
    if [ -d "$SUBJECTDIR"/"$SUBDIRECTORY"/${PREFIX}${NameOffMRI} ]; then
        rm -rf "$SUBJECTDIR"/"$SUBDIRECTORY"/${PREFIX}${NameOffMRI}
    fi
	mkdir -p "$SUBJECTDIR"/"$SUBDIRECTORY"/${PREFIX}${NameOffMRI}
	ln -s "$SUBJECTDIR"/${NameOffMRI}/* "$SUBJECTDIR"/"$SUBDIRECTORY"/${PREFIX}${NameOffMRI}/
	cp --remove-destination ICA_AROMA/${NameOffMRI}/denoised_func_data_${NOISE_OPT/both/aggr}.nii.gz "$SUBJECTDIR"/"$SUBDIRECTORY"/${PREFIX}${NameOffMRI}/${NameOffMRI}_nonlin_norm.nii.gz
    
    # rename files so that NameOffMRI is consistent
    for f_path in `ls -d "$SUBJECTDIR"/${PREFIX}${NameOffMRI}/*`; do
        f=`basename ${f_path}`
        path=`dirname ${f_path}`
        if [[ $f == "tfMRI_"* ]] || [[ $f == "rfMRI_"* ]]; then
            mv ${f_path} ${path}/ica_${f}
        fi
    done
    
    # copy link outputs to results folder
    mkdir -p "$SUBJECTDIR"/MNINonLinear/Results/${PREFIX}${NameOffMRI}
    cp -r "$SUBJECTDIR"/${PREFIX}${NameOffMRI}/* "$SUBJECTDIR"/"$SUBDIRECTORY"/MNINonLinear/Results/${PREFIX}${NameOffMRI}
    mv "$SUBJECTDIR"/MNINonLinear/Results/${PREFIX}${NameOffMRI}/${PREFIX}${NameOffMRI}_nonlin_norm.nii.gz "$SUBJECTDIR"/MNINonLinear/Results/${PREFIX}${NameOffMRI}/${PREFIX}${NameOffMRI}.nii.gz
    mv "$SUBJECTDIR"/MNINonLinear/Results/${PREFIX}${NameOffMRI}/${PREFIX}${NameOffMRI}_SBRef_nonlin_norm.nii.gz "$SUBJECTDIR"/MNINonLinear/Results/${PREFIX}${NameOffMRI}/${PREFIX}${NameOffMRI}_SBRef.nii.gz

done
popd > /dev/null
