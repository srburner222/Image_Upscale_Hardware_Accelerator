from PIL import Image
import numpy as np
import cv2
import os
import sys
import subprocess


# Function to turn an image (.jpg) to a 3D matrix (R,G,B)
def image_to_rgb_matrix(image_path):
    # Open the image
    image = Image.open(image_path)
    
    # Convert the image to RGB mode (in case it's not already)
    image = image.convert('RGB')
    
    # Get the size of the image
    width, height = image.size
    
    # Split the image into R, G, and B components
    r, g, b = image.split()
    
    # Convert the R, G, and B components to numpy arrays
    r_array = np.array(r)
    g_array = np.array(g)
    b_array = np.array(b)
    
    # Create a 3D matrix to represent the image, with dimensions (height, width, 3)
    rgb_matrix = np.zeros((height, width, 3), dtype=np.uint8)
    
    # Assign the R, G, and B components to the corresponding channels in the matrix
    rgb_matrix[:,:,0] = r_array
    rgb_matrix[:,:,1] = g_array
    rgb_matrix[:,:,2] = b_array
    
    return rgb_matrix


# Function to turn matrix from decimal to binary
def rgb_decimal_to_binary(rgb_matrix):
    # Convert decimal RGB values to binary representation
    binary_matrix = np.vectorize(np.binary_repr)(rgb_matrix, width=8)
    return binary_matrix

# Function to combine each element of 3D matrix (8-bit) into a single valued (24-bit) list
def combine_binary_to_24_bit(binary_matrix):
    combined_numbers = []
    height, width, _ = binary_matrix.shape
    for i in range(height):
        for j in range(width):
            combined = 0
            for k in range(3):
                combined = (combined << 8) | int(''.join(str(bit) for bit in binary_matrix[i, j, k]), 2)
            # Format the combined number as a binary string with leading zeros to ensure it has 24 bits
            combined_binary = format(combined, '024b')
            # Append op-code & 52 zeros to the front of the binary string
            combined_binary = '0001' + ('0' * 52) + combined_binary
            combined_numbers.append(combined_binary)
    return combined_numbers

# Function to write binary data (R,G,B) to a text file
def write_combined_numbers_to_file(combined_numbers, filename):
    with open(filename, 'w') as f:
        for num in combined_numbers:
            f.write(f"{num}\n")
        f.write(f"01100000000000000000000000000000000000000000000011111111111111111111111111111111\n")
        f.write(f"01010000000000000000000000000000000000000000000000000000000000000000000000000000\n")
        f.write(f"00110000000000000000000000000000000000000000000000000000000000000000000000000000")


# Function to write module parameters to a vh file
def write_params (filename, image_path):
    image = Image.open(image_path)
    width, height = image.size
    with open(filename, 'w') as f:
        f.write(f" localparam HRES = {width};\n localparam VRES = {height};")

def parse_image (filename, image_path):

    image = Image.open(image_path)
    h_res, v_res = image.size

    new_v_res = 2 * v_res
    new_h_res = 2 * h_res

    #Create image array & load file for module outputs
    outimage = np.zeros((new_v_res, new_h_res, 3))
    outfile = np.loadtxt("Outfile/out.txt")

    #Process output file into image array
    for i in range(0, new_v_res):
        for j in range (0, new_h_res):
            outimage[i, j, 0] = outfile[(i*new_h_res + j)*3 + 2]
            outimage[i, j, 1] = outfile[(i*new_h_res + j)*3 + 1]
            outimage[i, j, 2] = outfile[(i*new_h_res + j)*3 + 0]
    path = "Output_Images/" + filename
    #Write images to output pngs
    cv2.imwrite(path, outimage)


print('Enter desired image name to upscale (include file extension!):')
image_name = input()

image_path = "Input_Images/" + image_name  # Replace "example_image.jpg" with the path to your image file
matrix = image_to_rgb_matrix(image_path)
binary_matrix = rgb_decimal_to_binary(matrix)
combined_numbers = combine_binary_to_24_bit(binary_matrix)

write_combined_numbers_to_file(combined_numbers, "v/bsg_trace_master_0.tr")
write_params ("v/parameters.vh", image_path)

subprocess.run("make clean-build", shell=True)
subprocess.run("make sim-rtl", shell=True)

parse_image(image_name, image_path)

