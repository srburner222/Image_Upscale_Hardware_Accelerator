# Image Upscale Hardware Accelerator 
## About the Project
### Purpose
Develop an ASIC that upscales images from 1080p to 4k. This chip was designed as a VLSI capstone project at the University of Washington. The challenge was to push a design from conception, through a digital design CAD flow, and end up with a fab-ready chip by the end of the process. 

While the ASIC was designed with 1080p →4k upscaling in mind, it is capable of any 4x upscale (MxN →2Mx2N). It is also parameterizable to work with any color depth, though defaults to 24-bit.

A testing harness was developed in parallel with the ASIC that allows for (almost) complete automation. From the terminal the user is prompted to give an input image and the level of simulation (RTL, Syn, PnR) and the harness handles the rest. A few minutes later the upscaled image and performance metrics are output to the user.
	
In terms of next steps with the project, there are several ideas that would improve upon the current design:
- Modify parameterization to allow for other scaling factors (non MxN →2Mx2N)
- Modify interpolation algorithm to implement edge-aware scaling to further reduce stair step effect along sharp edges
- Modify architecture to allow for multiple frames (video) to be processed sequentially

For additional information about chip architecture or design process:
- [Milestone 1 (proposal)](https://youtu.be/3PRTdwjhe_o)  
- [Milestone 2](https://youtu.be/YJnEHGv7G6w)  
- [Milestone 3](https://youtu.be/G7C5A7b6-pM)  
- [Milestone 4](https://youtu.be/lWZpImCLfVo)  
- [Final milestone](https://youtu.be/XeLZKv3kYsg)  
### Example Images
These images are the result of a place and route version of the chip.
Note: Images are not 1080p →4k upscale and therefore not fully representative of the design capabilities.

Original image             |  Upscaled image
:-------------------------:|:-------------------------:
![shmol](https://github.com/srburner222/Image_Upscale_Hardware_Accelerator/assets/170982272/9a1c232a-0ceb-4bc8-82dd-a4f48c9d74e3)   |  ![myson](https://github.com/srburner222/Image_Upscale_Hardware_Accelerator/assets/170982272/6db2f4d7-30a2-4c80-b455-ad6d204c8f41)
![tiesmall](https://github.com/srburner222/Image_Upscale_Hardware_Accelerator/assets/170982272/66144adf-b455-4c27-a041-2efee22c2b2b)  |  ![tieupscale](https://github.com/srburner222/Image_Upscale_Hardware_Accelerator/assets/170982272/85867219-f38c-4a9c-a846-33ca0b80cc4b)











### Performance metrics
The PPA metrics of the chip have been recorded for a 1080p →4k upscale. The 14nm process values are extrapolated from the 130nm process values using Dennard Scaling to get a PPA estimate in a newer technology. The ASIC has also been compared against a Python implementation of the upscale algorithm, where the performance of the software is nowhere comparable to the accelerator.

![performance](https://github.com/srburner222/Image_Upscale_Hardware_Accelerator/assets/170982272/2707bba2-626d-496f-a442-68e265791f7f)

### Using the chip
**Device interface:**  
module interpolation #(parameter bit_depth = 8, parameter v_res = N, parameter h_res = M)  
(  
&nbsp;&nbsp; input logic    	    	          clk, reset,  
&nbsp;&nbsp; input logic                     valid_in,  
&nbsp;&nbsp; input logic  [bit_depth-1:0]    data_in,  
&nbsp;&nbsp; output logic    	              valid_out, ready_out,  
&nbsp;&nbsp; output logic [bit_depth-1:0]    data_out  
);  


- N & M can be replaced with the input image dimensions. If testing with our test script, this is done automatically  
- This chip uses a valid/ready interface. The chip will only accept data alongside valid_in = 1, and the only valid data out of the chip will be accompanied by valid_out = 1. When the chip is ready for new data, ready_out is asserted.  
- Data_out cannot be slowed. Our modules assume that the receiving module will be able to handle the output data rate. Depending on the application, a FIFO may be necessary.  
- When ready_out is not asserted, the module assumes no data will be skipped on the data_in port.  
## Getting started
### Disclaimer:
This CAD flow and test suite are designed to work with the HAMMER CAD flow in addition to the Cadence & Synopsys tools we have provided and used in development. We make no guarantee that this repository will work as-is in all CAD flows or with modifications. 

### Dependencies  
**Python**  
- [Pillow](https://pypi.org/project/pillow/)  
- [Numpy](https://numpy.org)  
- [Opencv-python](https://opencv.org)

**CAD flow tools**  
- [Hammer VLSI](https://github.com/bsg-external/hammer)  
- [Hammer BSG plugins](https://github.com/bsg-external/hammer-bsg-plugins)  
- [Hammer Cadence plugins](https://github.com/bsg-external/hammer-cadence-plugins)  

**Bespoke Silicon Group (BSG) repositories**  
- [Bsg_chip testing framework](https://github.com/bsg-external/ee478-designs-project) (pre-included in this repository with required modifications)    
- [Basejump_stl](https://github.com/bsg-external/basejump_stl_regression) (outdated, Verilog)  

&nbsp;&nbsp;OR

- [Basejump_stl](https://github.com/bespoke-silicon-group/basejump_stl ) (updated, SystemVerilog)*  

*Note: the config files assume the dependencies will be written in .v files. If you choose to use the newer version of basejump_stl, please make sure you update the configs.  


**Additional dependencies**  
- Synopsys VCS  
- Cadence Genus  
- Cadence Innovus  

### Install
**1. Clone the upscaler accelerator repository**  
   
&nbsp;&nbsp;&nbsp;&nbsp;Git clone https://github.com/srburner222/Image_Upscale_Hardware_Accelerator  

**2. Clone the HAMMER CAD flow**  
   
&nbsp;&nbsp;&nbsp;&nbsp;Git clone https://github.com/bsg-external/hammer   
&nbsp;&nbsp;&nbsp;&nbsp;Git clone https://github.com/bsg-external/hammer-bsg-plugins  
&nbsp;&nbsp;&nbsp;&nbsp;Git clone https://github.com/bsg-external/hammer-cadence-plugins 

**3. Clone basejump_stl (see dependencies for other options)**  
   
&nbsp;&nbsp;&nbsp;&nbsp;Git clone https://github.com/bsg-external/basejump_stl_regression  

**4. Install Python Packages (Requires Anaconda3 and pip install)**  
    
&nbsp;&nbsp;&nbsp;&nbsp;Pip install pillow  
&nbsp;&nbsp;&nbsp;&nbsp;Pip install numpy  
&nbsp;&nbsp;&nbsp;&nbsp;Pip install opencv-python *  

*Note: the current build for opencv takes a very long time to build its wheel. We have had success with specifying a version number to remedy this.  

### Usage (testbench)  
**1. Place your desired image into the “Input_Images” directory**  
**2. Enter the “Upscaler” directory**  
   
&nbsp;&nbsp;&nbsp;&nbsp;cd upscaler

**3. Run verification script**  
   
&nbsp;&nbsp;&nbsp;&nbsp;python3 runsim.py  

**4. Input the name and extension of the file you want to simulate with**  

&nbsp;&nbsp;&nbsp;&nbsp;\<image name>.\<file ext>  

**5. Select the type of simulation to run (1. RTL, 2. Syn, 3. PaR)**  
   
&nbsp;&nbsp;&nbsp;&nbsp;\<Simulation number>  

**6. After the simulation has run, the upscaled image should be available in the “Output_Images” folder for verification**  

## License
This repository was created by Nate Hancock & Shawn Burner as a capstone design project for EE 478 at the University of Washington.  

Copyright 2024 Nate Hancock & Shawn Burner. Copyright and related rights are licensed under the Solderpad Hardware License, Version 0.51 (the “License”); you may not use these files except in compliance with the License. You may obtain a copy of the License at http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law or agreed to in writing, software, hardware and materials distributed under this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.  

## Contact
**&nbsp;&nbsp;&nbsp;&nbsp;Shawn Burner - https://www.linkedin.com/in/shawnburner/**  
**&nbsp;&nbsp;&nbsp;&nbsp;Nate Hancock - https://www.linkedin.com/in/natechancock/**  

## Acknowledgements
- [Some files modified from bsg_chip testing framework](https://github.com/bsg-external/ee478-designs-project)  
- [Base interpolation architecture based on this paper from the University of Clermont Auvergn](https://ieeexplore.ieee.org/document/9257189)  
- [Instruction and assistance from our course instructor Michael Taylor](http://michaeltaylor.org/)  
