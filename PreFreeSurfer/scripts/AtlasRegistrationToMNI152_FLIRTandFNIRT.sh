#!/bin/bash 
set -e

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: FSLDIR

################################################ SUPPORT FUNCTIONS ##################################################

Usage() {
  echo "`basename $0`: Tool for non-linearly registering T1w and T2w to MNI space (T1w and T2w must already be registered together)"
  echo " "
  echo "Usage: `basename $0` [--workingdir=<working dir>]"
  echo "                --t1=<t1w image>"
  echo "                --t1rest=<bias corrected t1w image>"
  echo "                --t1restbrain=<bias corrected, brain extracted t1w image>"
  echo "                --t2=<t2w image>"
  echo "	 	--t2rest=<bias corrected t2w image>"
  echo "                --t2restbrain=<bias corrected, brain extracted t2w image>"
  echo "                --ref=<reference image>"
  echo "                --refbrain=<reference brain image>"
  echo "                --refmask=<reference brain mask>"
  echo "                [--ref2mm=<reference 2mm image>]"
  echo "                [--ref2mmmask=<reference 2mm brain mask>]"
  echo "                --owarp=<output warp>"
  echo "                --oinvwarp=<output inverse warp>"
  echo "                --ot1=<output t1w to MNI>"
  echo "                --ot1rest=<output bias corrected t1w to MNI>"
  echo "                --ot1restbrain=<output bias corrected, brain extracted t1w to MNI>"
  echo "                --ot2=<output t2w to MNI>"
  echo "		--ot2rest=<output bias corrected t2w to MNI>"
  echo "                --ot2restbrain=<output bias corrected, brain extracted t2w to MNI>"
  echo "                [--fnirtconfig=<FNIRT configuration file>]"
  echo "                --useT2=<false in T2w image is unavailable, default is true>"
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

# Outputs (in $WD):  xfms/acpc2MNILinear.mat  
#                    xfms/${T1wRestoreBrainBasename}_to_MNILinear  
#                    xfms/IntensityModulatedT1.nii.gz  xfms/NonlinearRegJacobians.nii.gz  
#                    xfms/IntensityModulatedT1.nii.gz  xfms/2mmReg.nii.gz  
#                    xfms/NonlinearReg.txt  xfms/NonlinearIntensities.nii.gz  
#                    xfms/NonlinearReg.nii.gz 
# Outputs (not in $WD): ${OutputTransform} ${OutputInvTransform}   
#                       ${OutputT1wImage} ${OutputT1wImageRestore}  
#                       ${OutputT1wImageRestoreBrain}
#                       ${OutputT2wImage}  ${OutputT2wImageRestore}  
#                       ${OutputT2wImageRestoreBrain}

################################################## OPTION PARSING #####################################################

# Just give usage if no arguments specified
if [ $# -eq 0 ] ; then Usage; exit 0; fi
# check for correct options
if [ $# -lt 17 ] ; then Usage; exit 1; fi

# parse arguments
WD=`getopt1 "--workingdir" $@`  # "$1"
T1wImage=`getopt1 "--t1" $@`  # "$2"
T1wRestore=`getopt1 "--t1rest" $@`  # "$3"
T1wRestoreBrain=`getopt1 "--t1restbrain" $@`  # "$4"
T2wImage=`getopt1 "--t2" $@`  # "$5"
T2wRestore=`getopt1 "--t2rest" $@`  # "$6"
T2wRestoreBrain=`getopt1 "--t2restbrain" $@`  # "$7"
Reference=`getopt1 "--ref" $@`  # "$8"
ReferenceBrain=`getopt1 "--refbrain" $@`  # "$9"
ReferenceMask=`getopt1 "--refmask" $@`  # "${10}"
Reference2mm=`getopt1 "--ref2mm" $@`  # "${11}"
Reference2mmBrain=`getopt1 "--ref2mmbrain" $@`
Reference2mmMask=`getopt1 "--ref2mmmask" $@`  # "${12}"
OutputTransform=`getopt1 "--owarp" $@`  # "${13}"
OutputInvTransform=`getopt1 "--oinvwarp" $@`  # "${14}"
OutputT1wImage=`getopt1 "--ot1" $@`  # "${15}"
OutputT1wImageRestore=`getopt1 "--ot1rest" $@`  # "${16}"
OutputT1wImageRestoreBrain=`getopt1 "--ot1restbrain" $@`  # "${17}"
OutputT2wImage=`getopt1 "--ot2" $@`  # "${18}"
OutputT2wImageRestore=`getopt1 "--ot2rest" $@`  # "${19}"
OutputT2wImageRestoreBrain=`getopt1 "--ot2restbrain" $@`  # "${20}"
FNIRTConfig=`getopt1 "--fnirtconfig" $@`  # "${21}"
useT2=`getopt1 "--useT2" $@` # "${22}"
usemask=`getopt1 "--usemask" $@` # "${23}"
T1wFolder=`getopt1 "--T1wFolder" $@` # "${24}"
useAntsReg=`getopt1 "--useAntsReg" $@`

# default parameters
WD=`defaultopt $WD .`
Reference2mm=`defaultopt $Reference2mm ${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz`
Reference2mmMask=`defaultopt $Reference2mmMask ${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz`
FNIRTConfig=`defaultopt $FNIRTConfig ${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf`


T1wRestoreBasename=`remove_ext $T1wRestore`;
T1wRestoreBasename=`basename $T1wRestoreBasename`;
T1wRestoreBrainBasename=`remove_ext $T1wRestoreBrain`;
T1wRestoreBrainBasename=`basename $T1wRestoreBrainBasename`;

echo " "
echo " START: AtlasRegistration to MNI152"

mkdir -p $WD

# Record the input options in a log file
echo "$0 $@" >> $WD/xfms/log.txt
echo "PWD = `pwd`" >> $WD/xfms/log.txt
echo "date: `date`" >> $WD/xfms/log.txt
echo " " >> $WD/xfms/log.txt

########################################## DO WORK ########################################## 

if "${useAntsReg:-false}"; then
    echo " ANTs Registration to MNI Template"
    # Create the warp field
    ${ANTSPATH}${ANTSPATH:+/}antsRegistrationSyN.sh -d 3 -f ${Reference2mm} -m ${T1wRestore}.nii.gz -o ${WD}/xfms/acpc_dc2standard_
    
    echo " Apply ANTs transform "
    # Apply the transofrmation (warp) to the T1wRestore and and T1wRestoreBrain
    ${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -r ${Reference} -i ${T1wImage}.nii.gz -e 0 -t ${WD}/xfms/acpc_dc2standard_1Warp.nii.gz -t ${WD}/xfms/acpc_dc2standard_0GenericAffine.mat -o ${OutputT1wImage}.nii.gz
    ${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -r ${Reference} -i ${T1wRestore}.nii.gz -e 0 -t ${WD}/xfms/acpc_dc2standard_1Warp.nii.gz -t ${WD}/xfms/acpc_dc2standard_0GenericAffine.mat -o ${OutputT1wImageRestore}.nii.gz
    ${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -r ${Reference} -i ${T1wRestoreBrain}.nii.gz -e 0 -t ${WD}/xfms/acpc_dc2standard_1Warp.nii.gz -t ${WD}/xfms/acpc_dc2standard_0GenericAffine.mat -o ${OutputT1wImageRestoreBrain}.nii.gz
    
    # Convert ANTS warp to FSL
    ${C3DPATH}${C3DPATH:+/}c4d -mcs ${WD}/xfms/acpc_dc2standard_1Warp.nii.gz -oo ${T1wFolder}/e{1..3}.nii.gz
    fslmaths ${T1wFolder}/e2.nii.gz -mul -1 ${T1wFolder}/e2.nii.gz
    fslmerge -t ${WD}/xfms/acpc_dc2standard.nii.gz ${T1wFolder}/e{1..3}.nii.gz
    # Convert ANTS mat to txt.mat
    ${C3DPATH}${C3DPATH:+/}c3d_affine_tool -itk ${WD}/xfms/acpc_dc2standard_0GenericAffine.mat -ref ${T1wRestore}.nii.gz -src ${Reference2mm} -ras2fsl -o ${WD}/xfms/acpc2MNILinear.mat

    if ${useT2}; then
        echo " Apply ANTs transform to T2w"
        # Apply the transofrmation (warp) to the T1wRestore and and T1wRestoreBrain
        ${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -r ${Reference} -i ${T2wImage}.nii.gz -e 0 -t ${WD}/xfms/acpc_dc2standard_1Warp.nii.gz -t ${WD}/xfms/acpc_dc2standard_0GenericAffine.mat -o ${OutputT2wImage}.nii.gz
        ${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -r ${Reference} -i ${T2wRestore}.nii.gz -e 0 -t ${WD}/xfms/acpc_dc2standard_1Warp.nii.gz -t ${WD}/xfms/acpc_dc2standard_0GenericAffine.mat -o ${OutputT2wImageRestore}.nii.gz
        ${ANTSPATH}${ANTSPATH:+/}antsApplyTransforms -d 3 -r ${Reference} -i ${T2wRestoreBrain}.nii.gz -e 0 -t ${WD}/xfms/acpc_dc2standard_1Warp.nii.gz -t ${WD}/xfms/acpc_dc2standard_0GenericAffine.mat -o ${OutputT2wImageRestoreBrain}.nii.gz
        
        # Convert ANTS warp to FSL
        #${C3DPATH}${C3DPATH:+/}c4d -mcs ${WD}/xfms/acpc_dc2standard_1Warp.nii.gz -oo ${T2wFolder}/e{1..3}.nii.gz
        #fslmaths ${T2wFolder}/e2.nii.gz -mul -1 ${T2wFolder}/e2.nii.gz
        #fslmerge -t ${WD}/xfms/acpc_dc2standard.nii.gz ${T2wFolder}/e{1..3}.nii.gz
        # Convert ANTS mat to txt.mat
        #${C3DPATH}${C3DPATH:+/}c3d_affine_tool -itk ${WD}/xfms/acpc_dc2standard_0GenericAffine.mat -ref ${T2wRestore}.nii.gz -src ${Reference2mm} -ras2fsl -o ${WD}/xfms/acpc2MNILinear.mat
    
    fi

    echo " Create Jacobian of the warp" 
    # Transform jacobian needed in HcpPost
    ${ANTSPATH}${ANTSPATH:+/}CreateJacobianDeterminantImage 3 ${WD}/xfms/acpc_dc2standard_1Warp.nii.gz ${WD}/xfms/NonlinearRegJacobians.nii.gz
    # Create invwarp
    ${FSLDIR}/bin/invwarp -w ${OutputTransform} -o ${OutputInvTransform} -r ${Reference2mm}

    # Create empty this empty file to satisfy expected outputs. Sorry. -Anonymous
    touch ${WD}/xfms/${T1wRestoreBrainBasename}_to_MNILinear.nii.gz
    
else
    # Linear then non-linear registration to MNI
    ${FSLDIR}/bin/flirt -interp spline -dof 12 -in ${T1wRestoreBrain} -ref ${ReferenceBrain} -omat ${WD}/xfms/acpc2MNILinear.mat -out ${WD}/xfms/${T1wRestoreBrainBasename}_to_MNILinear

    # Check for the usemask flag. If true, generate a mask of the T1w_restore_brain and include it in the FNIRT command. If false, run fnirt without inputting a T1w_restore mask. EF 20170330

    if $usemask; then
        fslmaths ${T1wRestoreBrain} -bin ${T1wFolder}/T1w_acpc_dc_restore_brain_mask.nii.gz
        #${FSLDIR}/bin/fnirt --in=${T1wRestore} --inmask=${T1wFolder}/brainmask_fs.nii.gz --ref=${Reference2mm} --aff=${WD}/xfms/acpc2MNILinear.mat --refmask=${Reference2mmMask} --fout=${OutputTransform} --jout=${WD}/xfms/NonlinearRegJacobians.nii.gz --refout=${WD}/xfms/IntensityModulatedT1.nii.gz --iout=${WD}/xfms/2mmReg.nii.gz --logout=${WD}/xfms/NonlinearReg.txt --intout=${WD}/xfms/NonlinearIntensities.nii.gz --cout=${WD}/xfms/NonlinearReg.nii.gz --config=${FNIRTConfig}
        ${FSLDIR}/bin/fnirt --in=${T1wRestore} --inmask=${T1wFolder}/T1w_acpc_dc_restore_brain_mask.nii.gz --ref=${Reference2mm} --aff=${WD}/xfms/acpc2MNILinear.mat --refmask=${Reference2mmMask} --fout=${OutputTransform} --jout=${WD}/xfms/NonlinearRegJacobians.nii.gz --refout=${WD}/xfms/IntensityModulatedT1.nii.gz --iout=${WD}/xfms/2mmReg.nii.gz --logout=${WD}/xfms/NonlinearReg.txt --intout=${WD}/xfms/NonlinearIntensities.nii.gz --cout=${WD}/xfms/NonlinearReg.nii.gz --config=${FNIRTConfig}
    else
        ${FSLDIR}/bin/fnirt --in=${T1wRestore} --ref=${Reference2mm} --aff=${WD}/xfms/acpc2MNILinear.mat --refmask=${Reference2mmMask} --fout=${OutputTransform} --jout=${WD}/xfms/NonlinearRegJacobians.nii.gz --refout=${WD}/xfms/IntensityModulatedT1.nii.gz --iout=${WD}/xfms/2mmReg.nii.gz --logout=${WD}/xfms/NonlinearReg.txt --intout=${WD}/xfms/NonlinearIntensities.nii.gz --cout=${WD}/xfms/NonlinearReg.nii.gz --config=${FNIRTConfig}
    fi

    # Input and reference spaces are the same, using 2mm reference to save time
    ${FSLDIR}/bin/invwarp -w ${OutputTransform} -o ${OutputInvTransform} -r ${Reference2mm}

    # T1w set of warped outputs (brain/whole-head + restored/orig)
    ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wImage} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImage}
    ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T1wRestore} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImageRestore}
    ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T1wRestoreBrain} -r ${Reference} -w ${OutputTransform} -o ${OutputT1wImageRestoreBrain}
    ${FSLDIR}/bin/fslmaths ${OutputT1wImageRestore} -mas ${OutputT1wImageRestoreBrain} ${OutputT1wImageRestoreBrain}

    if $useT2; then
        # T2w set of warped outputs (brain/whole-head + restored/orig)
        ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T2wImage} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImage}
        ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${T2wRestore} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImageRestore}
        ${FSLDIR}/bin/applywarp --rel --interp=nn -i ${T2wRestoreBrain} -r ${Reference} -w ${OutputTransform} -o ${OutputT2wImageRestoreBrain}
        ${FSLDIR}/bin/fslmaths ${OutputT2wImageRestore} -mas ${OutputT2wImageRestoreBrain} ${OutputT2wImageRestoreBrain}
    fi
fi
echo " "
echo " END: AtlasRegistration to MNI152"
echo " END: `date`" >> $WD/xfms/log.txt

########################################## QA STUFF ########################################## 

if [ -e $WD/xfms/qa.txt ] ; then rm -f $WD/xfms/qa.txt ; fi
echo "cd `pwd`" >> $WD/xfms/qa.txt
echo "# Check quality of alignment with MNI image" >> $WD/xfms/qa.txt
echo "fslview ${Reference} ${OutputT1wImageRestore}" >> $WD/xfms/qa.txt
if $useT2; then echo "fslview ${Reference} ${OutputT2wImageRestore}" >> $WD/xfms/qa.txt; fi

##############################################################################################
