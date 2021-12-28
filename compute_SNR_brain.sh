#!/bin/bash
#
# Script computates SNR from the input 3D image of the brain using two methods:
#
# 1. Mean signal from WM (mean_wm) and mean signal of noise extracted from
# four cubic ROIs placed in superior corners of the input 3D image (mean_noise).
#
# SNR = mean_wm / mean_noise
#
# 2. Mean signal from WM (mean_wm) and standard deviation (sd) of noise extracted from
# four cubic ROIs placed in the superior corners of the input 3D image (sd_noise).
# Moreover factor of 0.655 is used due to the Rician distribution of the background
# noise in a magnitude MR image:
#
# Z. Zhang et al., "Can Signal-to-Noise Ratio Perform as a Baseline Indicator
# for Medical Image Quality Assessment," in IEEE Access, 2018, doi: 10.1109/ACCESS.2018.2796632.
#
# SNR = 0.655 * mean_wm / sd_noise
#
# WARNING: scipt overwrittes existing results if they already exist
#
# USAGE:
# 	compute_SNR_brain.sh [-i <file_name>]
# EXAMPLE:
# 	compute_SNR_brain.sh -i t1.nii.gz
#
#
# Jan Valosek, Pavel Hok; fMRI laboratory Olomouc; 2020-2021
# Thanks for contribution to Dominik Vilimek from Technical University Ostrava

# REQUIREMENTS:
#   - FMRIB Software Library (FSL)

# TODO:
#   - if snr_dir already exists, backup it (currently it is overwritten)
#   - round output numbers to same number of decimals

# Initialization function and argument parser
init()
{
  # if number of input arguments is equal to zero, print usage
  [ $# -eq 0 ] && usage

  # input arguments parser
  while getopts ":hi:" arg; do
    case $arg in
      i) # Specify input file name
        file_name=${OPTARG}
        ;;
      h | *) # Display help.
        usage
        exit 0
        ;;
    esac
  done

  # check if input filename was passed
  if [[ ${file_name} == "" ]]; then
      echo "Option -i requires <file_name>."
      usage
  fi

  # check if input file exists
  if [[ ! -f ${file_name} ]];then
    echo "Input file ${file_name} does not exist."
    exit 1
  fi

  # call main function
  main ${file_name}

}

# Funtion for printing usage into terminal
usage()
{
    script_name=$(basename "$0")
    echo -e "USAGE:\n\t${script_name} [-i <file_name>]\nEXAMPLE:\n\t${script_name} -i t1.nii.gz\n"
    echo "Script for computation of SNR from the input 3D image of the brain using two methods:"
    echo "SNR = mean_wm / mean_noise"
    echo "SNR = 0.655 * mean_wm / sd_noise"
    echo "(Zhang et al., 2018, doi: 10.1109/ACCESS.2018.2796632)"
    echo -e "\nScript computes mean signal from WM (mean_wm) and mean or SD noise intensity from"
    echo "four cubic ROIs placed in the superior corners of the input 3D image (mean_noise)."
    echo -e "\nWARNING: scipt overwrittes existing results if they already exist"
    echo -e "\nREQUIREMENTS: FMRIB Software Library (FSL)"
    echo -e "\nJan Valosek, Pavel Hok; fMRI laboratory Olomouc; 2020-2021"
    echo -e "Thanks for contribution to Dominik Vilimek from Technical University Ostrava"
    exit
}


# Main function
main()
{
      # remove file suffix (.nii.gz is expected)
      file_name=$(basename $1 .nii.gz)

      # Log where computations will be saved
      log_file="snr_${file_name}.txt"

      # create working dirrectory (e.g., snr_t1 or snr_Mprage) where everything will be stored
      snr_dir=snr_${file_name}
      if [[ ! -d ${snr_dir} ]];then mkdir ${snr_dir};fi

      # copy input image to working dir
      cp ${file_name}.nii.gz ${snr_dir}/
      cd ${snr_dir}/

      # print info about the image into ouput txt file
      echo -e "${file_name}.nii.gz" | tee -a ${log_file}
      echo -e "$(fslinfo ${file_name}.nii.gz)\n" | tee -a ${log_file}

      # reorient image to match the approximate orientation of the standard template images (MNI152)
      fslreorient2std ${file_name}.nii.gz ${file_name}_reorient.nii.gz

      # perfrom brain extraction
      echo "Starting brain extraction..."
      bet ${file_name}_reorient.nii.gz ${file_name}_brain.nii.gz -B -f 0.3

      # perform WM, GM and CSF segmentations
      echo "Starting structural segmentaion..."
      fast -B ${file_name}_brain.nii.gz

      # create mask of WM (threshold to 0.5 and binarize)
      echo "Starting computation of SNR..."
      fslmaths ${file_name}_brain_pve_2.nii.gz -thr 0.5 -bin ${file_name}_brain_pve_2_bin.nii.gz

      # compute mean intenstity from WM (-k is mask)
      mean_wm=$(fslstats ${file_name}_brain.nii.gz -k ${file_name}_brain_pve_2_bin.nii.gz -M)
      echo -e "\nMean signal from WM: ${mean_wm}" | tee -a ${log_file}

      # create ROIs
      create_roi ${file_name}

      # compute SNR = mean_wm / mean_noise
      compute_noise_basic ${file_name} ${mean_wm}

      # compute SNR = 0.655 * mean_wm / sd_noise
      compute_noise_rician ${file_name} ${mean_wm}

      exit
}

# Create 4 cubic ROIs in superior corners of input 3D image
create_roi()
{
      # fetch input image dimensions
      dim_1=$(fslval ${file_name}_reorient.nii.gz dim1)
      dim_2=$(fslval ${file_name}_reorient.nii.gz dim2)
      dim_3=$(fslval ${file_name}_reorient.nii.gz dim3)

      # compute coordinates for ROI in Left Anterior Superior corner
      dif_1=$(echo $dim_1 - 20 | bc)
      dif_2=$(echo $dim_2 - 20 | bc)
      dif_3=$(echo $dim_3 - 20 | bc)

      # Create 4 ROIs in superior corners of input 3D image
      # Left Anterior Superior corner
      fslroi ${file_name}_reorient.nii.gz ${file_name}_roi_LAS.nii.gz ${dif_1} 10 ${dif_2} 10 ${dif_3} 10
      # Left Posterior Superior corner
      fslroi ${file_name}_reorient.nii.gz ${file_name}_roi_LPS.nii.gz ${dif_1} 10 20 10 ${dif_3} 10
      # Right Posterior Superior corner
      fslroi ${file_name}_reorient.nii.gz ${file_name}_roi_RPS.nii.gz 20 10 20 10 ${dif_3} 10
      # Right Anterior Superior corner
      fslroi ${file_name}_reorient.nii.gz ${file_name}_roi_RAS.nii.gz 20 10 ${dif_2} 10 ${dif_3} 10
}

# SNR = mean_wm / mean_noise
compute_noise_basic()
{

      echo -e "\nMethod 1 (SNR = mean_wm / mean_noise):"
      # Compute mean noise for each ROI and mean noise across all ROIs
      noise_sum=0
      for roi in LAS LPS RPS RAS;do     # loop across individual ROI

          noise=$(fslstats ${file_name}_roi_${roi}.nii.gz -M)       # compute mean intensity for given ROI
          noise_sum=$(echo ${noise_sum} + ${noise} | bc)            # sum mean intensity from individual ROIs
          echo "Mean noise for ${roi} ROI: ${noise}" | tee -a ${log_file}

      done

      mean_noise=$(echo ${noise_sum} / 4 | bc -l)      # compute mean intenstiy of noise across all ROIs
      echo "Mean noise across all ROI: ${mean_noise}" | tee -a ${log_file}

      SNR=$(echo ${mean_wm} / ${mean_noise} | bc -l)
      echo "SNR: ${SNR}" | tee -a ${log_file}
}

# SNR = 0.655 * mean_wm / sd_noise
compute_noise_rician()
{

      echo -e "\nMethod 2 (SNR = 0.655 * mean_wm / sd_noise):"
      # Compute standard deviation of pixel intensities across all ROI
      noise_sum=0
      for roi in LAS LPS RPS RAS;do     # loop across individual ROI

          noise=$(fslstats ${file_name}_roi_${roi}.nii.gz -S)       # compute SD intensity for given ROI
          noise_sum=$(echo ${noise_sum} + ${noise} | bc)            # sum mean intensity from individual ROIs
          echo "SD of noise for ${roi} ROI: ${noise}" | tee -a ${log_file}

      done

      sd_noise=$(echo ${noise_sum} / 4 | bc -l)      # compute SD of noise across all ROIs
      echo "SD of noise across all ROI: ${sd_noise}" | tee -a ${log_file}

      SNR_SD=$(echo ${mean_wm} / ${sd_noise} \* 0.655 | bc -l)    # factor of 0.655 is due to the Rician distribution of the background noise in a magnitude MR image
      echo "SNR: ${SNR_SD}" | tee -a ${log_file}
}

init "$@"
