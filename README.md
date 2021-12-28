# Compute SNR brain
Compute Signal-to-Noise Ratio (SNR) from the 3D MRI image of the brain using FSL tools

#### USAGE:

clone repository:

`git clone https://github.com/valosekj/compute_snr_brain.git`

run script:

`compute_SNR_brain.sh [-i <file_name>]`

#### DETAILS:

Script performs:

1. Reorientation of the input image to match the approximate orientation of the standard template image (MNI152)

2. Brain extraction

3. Tissue-type segmentation (WM, GM, CSF)

4. Creation of WM mask

5. Creation of four cubic ROIs places in the superior corners of the input 3D image representing noise 

6. Computation of SNR using two methods:

    - SNR = mean_wm / mean_noise

    - SNR = 0.655 * mean_wm / sd_noise 
    
        (Zhang et al., IEEE Access, 2018, doi: [10.1109/ACCESS.2018.2796632](https://ieeexplore.ieee.org/document/8267028))
    
Computed SNR (saved into `snr.txt` file) as well as all processed images are stored in newly created directory.


#### AUTHORS:
Jan Valošek, Pavel Hok; fMRI laboratory Olomouc

Thanks for contribution to Dominik Vilimek from Technical University Ostrava
