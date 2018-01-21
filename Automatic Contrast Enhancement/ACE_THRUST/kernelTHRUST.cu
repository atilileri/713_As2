/*
* 713_Assignment 2
* In the assignment, I will implement a Automatic Contrast Enhancement algorithm with Parallel Reduction on CUDA.
*
* Algortihm and strategies are my own.
* This file contains the CUDA version of the algorithm.
*/

#include <iostream>
#include <fstream>
#include <sstream>
#include <stdio.h>
#include <stdlib.h>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "npp.h"
#include <windows.h>
#include <thrust/host_vector.h>
#include <thrust/device_vector.h>
#include <thrust/extrema.h>
#include <thrust/functional.h>

//global variables for and function declerations for performance measurements
double PCFreq = 0.0;
__int64 CounterStart = 0;
void StartCounter();
double GetCounter();

// Function declarations.
thrust::host_vector<Npp8u>
LoadPGM(char * sFileName, int & nWidth, int & nHeight, int & nMaxGray);

void
WritePGM(char * sFileName, thrust::host_vector<Npp8u> pDst_Host, int nWidth, int nHeight, int nMaxGray);

// Main function.
int
main(int argc, char ** argv)
{
	// Host parameter declarations.	
	int   nWidth, nHeight, nMaxGray;

	std::cout << "####### THRUST VERSION #######" << std::endl;

	// Load image to the host.
	std::cout << "Load PGM file." << std::endl;
	thrust::host_vector<Npp8u> vecHost = LoadPGM("..\\input\\lena_before.pgm", nWidth, nHeight, nMaxGray);
	// Device parameter declarations.
	Npp8u nMin, nMax;

	// Copy the image from the host to GPU
	thrust::device_vector<Npp8u> vecDev = vecHost;
	std::cout << "Copy image from host to device." << std::endl;
	std::cout << "Process the image on GPU." << std::endl;

	//start counter for performance mesaurements
	StartCounter();

	// Compute the min and the max.
	nMin = thrust::reduce(vecDev.begin(), vecDev.end(), nMaxGray, thrust::minimum<int>());
	nMax = thrust::reduce(vecDev.begin(), vecDev.end(), 0, thrust::maximum<int>());

	std::cout << "Duration after MinMax: " << GetCounter() << " microseconds" << std::endl;

	// Compute the optimal nConstant and nScaleFactor for integer operation see GTC 2013 Lab NPP.pptx for explanation
	// I will prefer integer arithmetic, Instead of using 255.0f / (nMax - nMin) directly
	int nScaleFactor = 0;
	int nPower = 1;
	while (nPower * 255.0f / (nMax - nMin) < 255.0f)
	{
		nScaleFactor++;
		nPower *= 2;
	}
	float nConstant = 255.0f / (nMax - nMin) * (nPower / 2);

	// Calculate nMultiplier by multiplying nConstant and divide by divider = 2 ^ (nScaleFactor-1)
	int nDivider = 1;
	for (int j = 0; j < nScaleFactor - 1; j++) nDivider <<= 1;

	float nMultiplier = nConstant / nDivider;
	
	// Subtract nMin and multiply by nMultiplier
	thrust::for_each(vecDev.begin(), vecDev.end(), thrust::placeholders::_1 = (thrust::placeholders::_1 - nMin) * nMultiplier);
		
	std::cout << "Duration of THRUST Run: " << GetCounter() << " microseconds" << std::endl;

	// Copy result back to the host.
	std::cout << "Work done! Copy the result back to host." << std::endl;
	vecHost = vecDev;

	// Output the result image.
	std::cout << "Output the PGM file." << std::endl;
	WritePGM("..\\output\\lena_after_THRUST.pgm", vecHost, nWidth, nHeight, nMaxGray);

	return 0;
}

// Disable reporting warnings on functions that were marked with deprecated.
#pragma warning( disable : 4996 )

// Load PGM file.
thrust::host_vector<Npp8u>
LoadPGM(char * sFileName, int & nWidth, int & nHeight, int & nMaxGray)
{
	char aLine[256];
	FILE * fInput = fopen(sFileName, "r");
	if (fInput == 0)
	{
		perror("Cannot open file to read");
		exit(EXIT_FAILURE);
	}
	// First line: version
	fgets(aLine, 256, fInput);
	std::cout << "\tVersion: " << aLine;
	// Second line: comment
	fgets(aLine, 256, fInput);
	std::cout << "\tComment: " << aLine;
	fseek(fInput, -1, SEEK_CUR);
	// Third line: size
	fscanf(fInput, "%d", &nWidth);
	std::cout << "\tWidth: " << nWidth;
	fscanf(fInput, "%d", &nHeight);
	std::cout << " Height: " << nHeight << std::endl;
	// Fourth line: max value
	fscanf(fInput, "%d", &nMaxGray);
	std::cout << "\tMax value: " << nMaxGray << std::endl;
	while (getc(fInput) != '\n');
	// Following lines: data
	thrust::host_vector<Npp8u> vecHost(nWidth * nHeight);
	for (int i = 0; i < nHeight; ++i)
		for (int j = 0; j < nWidth; ++j)
			vecHost[i*nWidth + j] = fgetc(fInput);
	fclose(fInput);

	return vecHost;
}

// Write PGM image.
void
WritePGM(char * sFileName, thrust::host_vector<Npp8u> vecHost, int nWidth, int nHeight, int nMaxGray)
{
	FILE * fOutput = fopen(sFileName, "wb");
	if (fOutput == 0)
	{
		perror("Cannot open file to read");
		exit(EXIT_FAILURE);
	}
	char * aComment = "# Created by NPP";
	fprintf(fOutput, "P5\n%s\n%d %d\n%d\n", aComment, nWidth, nHeight, nMaxGray);
	for (int i = 0; i < nHeight; ++i)
		for (int j = 0; j < nWidth; ++j)
			fputc(vecHost[i*nWidth + j], fOutput);
	fclose(fOutput);
}

void StartCounter()
{
	LARGE_INTEGER li;
	if (!QueryPerformanceFrequency(&li))
		std::cout << "QueryPerformanceFrequency failed!\n";

	PCFreq = double(li.QuadPart) / 1000000.0;

	QueryPerformanceCounter(&li);
	CounterStart = li.QuadPart;
}
double GetCounter()
{
	LARGE_INTEGER li;
	QueryPerformanceCounter(&li);
	return double(li.QuadPart - CounterStart) / PCFreq;
}
