
#include <iostream>
#include <fstream>
#include <sstream>
#include <stdio.h>
#include <stdlib.h>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "npp.h"



// Main function.
int
main(int argc, char ** argv)
{
	// Host parameter declarations.	
	Npp8u * pSrc_Host, *pDst_Host;
	int   nWidth, nHeight, nMaxGray;

	std::cout << "####### CUDA VERSION #######" << std::endl;

	// Load image to the host.
	std::cout << "Load PGM file." << std::endl;
	//pSrc_Host = LoadPGM("..\\input\\lena_before.pgm", nWidth, nHeight, nMaxGray);
	pSrc_Host = new Npp8u[nWidth * nHeight];
	pDst_Host = new Npp8u[nWidth * nHeight];

	// Device parameter declarations.
	Npp8u	 * pSrc_Dev, *pDst_Dev;
	Npp8u    * pMin_Dev, *pMax_Dev;
	Npp8u    * pBuffer_Dev;
	Npp8u    nMin_Host, nMax_Host;
	NppiSize oROI;
	int		 nSrcStep_Dev, nDstStep_Dev;
	int		 nBufferSize_Host = 0;

	// Copy the image from the host to GPU
	oROI.width = nWidth;
	oROI.height = nHeight;
	pSrc_Dev = nppiMalloc_8u_C1(nWidth, nHeight, &nSrcStep_Dev);
	pDst_Dev = nppiMalloc_8u_C1(nWidth, nHeight, &nDstStep_Dev);
	std::cout << "Copy image from host to device." << std::endl;
	cudaMemcpy2D(pSrc_Dev, nSrcStep_Dev, pSrc_Host, nWidth, nWidth, nHeight, cudaMemcpyHostToDevice);

	std::cout << "Process the image on GPU." << std::endl;
	// Allocate device buffer for the MinMax primitive -- this is only necessary for nppi, we can simply return into nMin_Host and n_Max_Host
	cudaMalloc(reinterpret_cast<void **>(&pMin_Dev), sizeof(Npp8u)); // You won't need these lines
	cudaMalloc(reinterpret_cast<void **>(&pMax_Dev), sizeof(Npp8u)); // You won't need these lines
	nppiMinMaxGetBufferHostSize_8u_C1R(oROI, &nBufferSize_Host);  // You won't need these lines 
	cudaMalloc(reinterpret_cast<void **>(&pBuffer_Dev), nBufferSize_Host); // You won't need these lines

																		   // REPLACE THIS PART WITH YOUR KERNELs
																		   // Compute the min and the max.
	nppiMinMax_8u_C1R(pSrc_Dev, nSrcStep_Dev, oROI, pMin_Dev, pMax_Dev, pBuffer_Dev); // // Replace this line with your KERNEL1 call (KERNEL1: your kernel calculating the minimum and maximum values and returning them here)
	cudaMemcpy(&nMin_Host, pMin_Dev, sizeof(Npp8u), cudaMemcpyDeviceToHost); // You won't need these lines to get the min and max. Return nMin_Host from your kernel function 
	cudaMemcpy(&nMax_Host, pMax_Dev, sizeof(Npp8u), cudaMemcpyDeviceToHost); // You won't need these lines to get the min and max. Return nMax_Host from your kernel function

	std::cout << "Min: " << static_cast<unsigned int>(nMin_Host) << " Max : " << static_cast<unsigned int>(nMax_Host) << std::endl;

	// Call SubC primitive.
	nppiSubC_8u_C1RSfs(pSrc_Dev, nSrcStep_Dev, nMin_Host, pDst_Dev, nDstStep_Dev, oROI, 0); // Replace this line with your KERNEL2 call (KERNEL2: your kernel subtracting the nMin_Host from all the pixels)

																							// Compute the optimal nConstant and nScaleFactor for integer operation see GTC 2013 Lab NPP.pptx for explanation
	int nScaleFactor = 0;
	int nPower = 1;
	while (nPower * 255.0f / (nMax_Host - nMin_Host) < 255.0f)
	{
		nScaleFactor++;
		nPower *= 2;
	}
	Npp8u nConstant = static_cast<Npp8u>(255.0f / (nMax_Host - nMin_Host) * (nPower / 2)); //you won't need these calculations

																						   // Call MulC primitive.
	nppiMulC_8u_C1IRSfs(nConstant, pDst_Dev, nDstStep_Dev, oROI, nScaleFactor - 1); // Replace this line with your KERNEL3 call (KERNEL3: your kernel multiplying all the pixels with the nConstant and then dividing them by nScaleFactor -1 to achieve: 255/(nMax_Host-nMinHost)))


																					//-------------------
																					// Copy result back to the host.
	std::cout << "Work done! Copy the result back to host." << std::endl;
	cudaMemcpy2D(pDst_Host, nWidth * sizeof(Npp8u), pDst_Dev, nDstStep_Dev, nWidth * sizeof(Npp8u), nHeight, cudaMemcpyDeviceToHost);

	// Output the result image.
	std::cout << "Output the PGM file." << std::endl;
	//WritePGM("..\\output\\lena_after_CUDA.pgm", pDst_Host, nWidth, nHeight, nMaxGray);

	// Clean up.
	std::cout << "Clean up." << std::endl;
	delete[] pSrc_Host;
	delete[] pDst_Host;

	nppiFree(pSrc_Dev);
	nppiFree(pDst_Dev);
	cudaFree(pBuffer_Dev);
	nppiFree(pMin_Dev);
	nppiFree(pMax_Dev);

	return 0;
}



//int *g_idata, int *g_odata
__global__ void MinMax8uGPU(Npp8u * pSrc_Host, NppiSize oROI, Npp8u & nMin_Host, Npp8u & nMax_Host)
{
	extern __shared__ Npp8u sdata[];
	// each thread loads one element from global to shared mem
	unsigned int tid = threadIdx.x;
	unsigned int i = blockIdx.x * blockDim.x + threadIdx.x;
	sdata[tid] = pSrc_Host[i];


	//// Each thread calculates C[row][col]
	//int row = blockIdx.y * blockDim.y + threadIdx.y;
	//int col = blockIdx.x * blockDim.x + threadIdx.x;
	//int temp = 0;
	//// Return if size is reached
	//if (row >= M || col >= P) return;
	////multiply every element and add to a temporary variable
	//for (int i = 0; i < N; i++)
	//{
	//	temp += A[(row * N) + i] * B[col + (i * P)];
	//}
	//C[(row * P) + col] = temp;
}
