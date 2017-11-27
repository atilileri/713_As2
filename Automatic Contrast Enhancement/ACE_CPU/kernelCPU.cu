/*
* 713_Assignment 2
* In the assignment, I will implement a Automatic Contrast Enhancement algorithm on CPU.
*
* Algortihm and strategies are my own.
* This file contains the CPU version of the algorithm.
*/

#include <iostream>
#include <fstream>
#include <sstream>
#include "npp.h"
#include <windows.h>

//global variables for and function declerations for performance measurements
double PCFreq = 0.0;
__int64 CounterStart = 0;
void StartCounter();
double GetCounter();

// Function declarations.
Npp8u *
LoadPGM(char * sFileName, int & nWidth, int & nHeight, int & nMaxGray);

void
WritePGM(char * sFileName, Npp8u * pDst_Host, int nWidth, int nHeight, int nMaxGray);

void
MinMax8uCPU(Npp8u * pSrc_Host, NppiSize oROI, Npp8u & nMin_Host, Npp8u & nMax_Host);

void
SubMin8uCPU(Npp8u * pDst_Host, Npp8u * pSrc_Host, NppiSize oROI, Npp8u nMin_Host);

void
MulDiv8uCPU(Npp8u * pDst_Host, NppiSize oROI, Npp8u nConstant, int nScaleFactorMinus1);


// Main function.
int
main(int argc, char ** argv)
{
	// Parameter declarations.
	// Since this is the CPU version, I only kept host parameters.
	// I did not change variable names for easier comparison.
	Npp8u * pSrc_Host, *pDst_Host;
	int   nMaxGray;
	Npp8u    nMin_Host=0, nMax_Host=0;
	NppiSize oROI;

	std::cout << "####### CPU VERSION #######" << std::endl;
	
	// Load image to the host.
	std::cout << "Load PGM file." << std::endl;
	pSrc_Host = LoadPGM("..\\input\\lena_before.pgm", oROI.width, oROI.height, nMaxGray);
	pDst_Host = new Npp8u[oROI.width * oROI.height];

	std::cout << "Process the image on CPU." << std::endl;

	//start counter for performance mesaurements
	StartCounter();

	// Compute the min and the max.
	MinMax8uCPU(pSrc_Host, oROI, nMin_Host, nMax_Host);

	// Subtract Min
	SubMin8uCPU(pDst_Host, pSrc_Host, oROI, nMin_Host);

	// Compute the optimal nConstant and nScaleFactor for integer operation see GTC 2013 Lab NPP.pptx for explanation
	// I will prefer integer arithmetic, Instead of using 255.0f / (nMax_Host - nMin_Host) directly
	int nScaleFactor = 0;
	int nPower = 1;
	while (nPower * 255.0f / (nMax_Host - nMin_Host) < 255.0f)
	{
		nScaleFactor++;
		nPower *= 2;
	}
	Npp8u nConstant = static_cast<Npp8u>(255.0f / (nMax_Host - nMin_Host) * (nPower / 2));

	// multiply by nConstant and divide by 2 ^ nScaleFactor-1
	MulDiv8uCPU(pDst_Host, oROI, nConstant, nScaleFactor - 1);
	
	std::cout << "Duration of CPU Run: " << GetCounter() << " microseconds" << std::endl;

	std::cout << "Work done!" << std::endl;

	// Output the result image.
	std::cout << "Output the PGM file." << std::endl;
	WritePGM("..\\output\\lena_after_CPU.pgm", pDst_Host, oROI.width, oROI.height, nMaxGray);

	// Clean up.
	std::cout << "Clean up." << std::endl;
	delete[] pSrc_Host;
	delete[] pDst_Host;

	return 0;
}

// Disable reporting warnings on functions that were marked with deprecated.
#pragma warning( disable : 4996 )

// Load PGM file.
Npp8u *
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
	Npp8u * pSrc_Host = new Npp8u[nWidth * nHeight];
	for (int i = 0; i < nHeight; ++i)
		for (int j = 0; j < nWidth; ++j)
			pSrc_Host[i*nWidth + j] = fgetc(fInput);
	fclose(fInput);

	return pSrc_Host;
}

// Write PGM image.
void
WritePGM(char * sFileName, Npp8u * pDst_Host, int nWidth, int nHeight, int nMaxGray)
{
	FILE * fOutput = fopen(sFileName, "w+");
	if (fOutput == 0)
	{
		perror("Cannot open file to read");
		exit(EXIT_FAILURE);
	}
	char * aComment = "# Created by NPP";
	fprintf(fOutput, "P5\n%s\n%d %d\n%d\n", aComment, nWidth, nHeight, nMaxGray);
	for (int i = 0; i < nHeight; ++i)
		for (int j = 0; j < nWidth; ++j)
			fputc(pDst_Host[i*nWidth + j], fOutput);
	fclose(fOutput);
}

// Calculate Min and Max
void
MinMax8uCPU(Npp8u * pSrc_Host, NppiSize oROI, Npp8u & nMin_Host, Npp8u & nMax_Host)
{
	nMin_Host = nMax_Host = pSrc_Host[0];

	for (Npp16u i = 0; i < oROI.height; i++)
	{
		for (Npp16u j = 0; j < oROI.width; j++)
		{
			if (nMin_Host > pSrc_Host[i * oROI.width + j])
			{
				nMin_Host = pSrc_Host[i * oROI.width + j];
			}
			else if (nMax_Host < pSrc_Host[i * oROI.width + j])
			{
				nMax_Host = pSrc_Host[i * oROI.width + j];
			}
		}
	}
}

// Subtract Min from Source and set it to Destination
void
SubMin8uCPU(Npp8u * pDst_Host, Npp8u * pSrc_Host, NppiSize oROI, Npp8u nMin_Host)
{
	for (Npp16u i = 0; i < oROI.height; i++)
	{
		for (Npp16u j = 0; j < oROI.width; j++)
		{
			pDst_Host[i * oROI.width + j] = pSrc_Host[i * oROI.width + j] - nMin_Host;
		}
	}
}

// multiply by nConstant and divide by 2 ^ nScaleFactor-1
void
MulDiv8uCPU(Npp8u * pDst_Host, NppiSize oROI, Npp8u nConstant, int nScaleFactorMinus1)
{
	for (Npp16u i = 0; i < oROI.height; i++)
	{
		for (Npp16u j = 0; j < oROI.width; j++)
		{
			pDst_Host[i * oROI.width + j] = static_cast<Npp8u>(round(pDst_Host[i * oROI.width + j] * nConstant / pow(2,nScaleFactorMinus1)));
		}
	}
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
