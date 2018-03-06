#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: as in SetUpHCPPipeline.sh   (or individually: FSLDIR, HCPPIPEDIR_Templates)

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Tool for performing brain extraction using non-linear (FNIRT) results"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>] --in=<input image> [--ref=<reference highres image>] [--refmask=<reference brain mask>] [--ref2mm=<reference image 2mm>] [--ref2mmmask=<reference brain mask 2mm>] --outbrain=<output brain extracted image> --outbrainmask=<output brain mask> [--fnirtconfig=<fnirt config file>]"
}

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

defaultopt() {
    echo $1
}

################################################### OUTPUT FILES #####################################################

# All except variables starting with $Output are saved in the Working Directory:
#     roughlin.mat "$BaseName"_to_MNI_roughlin.nii.gz   (flirt outputs)
#     NonlinearRegJacobians.nii.gz IntensityModulatedT1.nii.gz NonlinearReg.txt NonlinearIntensities.nii.gz 
#     NonlinearReg.nii.gz (the coefficient version of the warpfield) 
#     str2standard.nii.gz standard2str.nii.gz   (both warpfields in field format)
#     "$BaseName"_to_MNI_nonlin.nii.gz   (spline interpolated output)
#    "$OutputBrainMask" "$OutputBrainExtractedImage"

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
#if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
#if [ $# -lt 4 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
Input=`getopt1 "--in" $@`  # "$2"
#Reference=`getopt1 "--ref" $@` # "$3"
#ReferenceMask=`getopt1 "--refmask" $@` # "$4"
#Reference2mm=`getopt1 "--ref2mm" $@` # "$5"
#Reference2mmMask=`getopt1 "--ref2mmmask" $@` # "$6"
OutputBrainExtractedImage=`getopt1 "--outbrain" $@` # "$7"
OutputBrainMask=`getopt1 "--outbrainmask" $@` # "$8"
#FNIRTConfig=`getopt1 "--fnirtconfig" $@` # "$9"
StudyTemplate=`getopt1 "--studytemplate" $@`
StudyTemplateBrain=`getopt1 "--studytemplatebrain" $@`
useT2=`getopt1 "--useT2" $@`
T1acpc=`getopt1 "--t1" $@`
T2acpc=`getopt1 "--t2" $@`

# default parameters
WD=`defaultopt $WD .`


echo " "
echo " START: antsSkullStrip.sh "

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/log.txt
echo "PWD = `pwd`" >> $WD/log.txt
echo "date: `date`" >> $WD/log.txt
echo " " >> $WD/log.txt


/home/exacloud/lustre1/fnl_lab/code/internal/utilities/Atlas_Image_Tools/atlas2Subject/antsSkullStrip.sh -i ${Input}.nii.gz -t ${StudyTemplate} -b ${StudyTemplateBrain} -o ${OutputBrainExtractedImage}.nii.gz -f ${WD} --keep-files --refine

echo " "
echo ${FSLDIR}/bin/fslmaths $OutputBrainExtractedImage -bin $OutputBrainMask

${FSLDIR}/bin/fslmaths $OutputBrainExtractedImage -bin $OutputBrainMask

echo " "


if $useT2 && [ -e "${T1acpc}_brain.nii.gz" ] && [ -e "${T2acpc}_brain.nii.gz" ]; then

	echo ${FSLDIR}/bin/flirt -in ${T1acpc}.nii.gz -ref ${T2acpc}.nii.gz -dof 6 -omat ${WD}/T1w2T2w_rigid.mat
	echo " "
	echo ${FSLDIR}/bin/flirt -in ${T1acpc}_brain.nii.gz -ref ${T2acpc}.nii.gz -applyxfm -init ${WD}/T1w2T2w_rigid.mat -out ${WD}/T1w2T2wh_rigid.nii.gz
	echo " "
	echo ${FSLDIR}/bin/fslmaths ${WD}/T1w2T2wh_rigid.nii.gz -bin ${WD}/T1w2T2wh_rigid_mask.nii.gz
	echo " "
	echo ${FSLDIR}/bin/fslmaths ${T2acpc}.nii.gz -mul ${WD}/T1w2T2wh_rigid_mask.nii.gz ${T2acpc}_brain.nii.gz
	echo " "

	${FSLDIR}/bin/flirt -in ${T1acpc}.nii.gz -ref ${T2acpc}.nii.gz -dof 6 -omat ${WD}/T1w2T2w_rigid.mat
	${FSLDIR}/bin/flirt -in ${T1acpc}_brain.nii.gz -ref ${T2acpc}.nii.gz -applyxfm -init ${WD}/T1w2T2w_rigid.mat -out ${WD}/T1w2T2wh_rigid.nii.gz
	${FSLDIR}/bin/fslmaths ${WD}/T1w2T2wh_rigid.nii.gz -bin ${WD}/T1w2T2wh_rigid_mask.nii.gz
	${FSLDIR}/bin/fslmaths ${T2acpc}.nii.gz -mul ${WD}/T1w2T2wh_rigid_mask.nii.gz ${T2acpc}_brain.nii.gz

fi

echo " "
echo " END: antsSkullStrip.sh "
echo " END: `date`" >> $WD/log.txt


