#include <iostream>
#include <fstream>
#include <string>
#include <cmath>
#include <vector>
#include <time.h>
#include "final.h"
#include <random>
#include <fstream>
using namespace std;

double* readfile(){
	ifstream in("./data/coef.txt");
	string filename;
	string line;
	int num = 0;
	if(in)
	{
		while (getline (in, line))
		{ 
			coef[num] = stod(line);
			num++;
		}
	}
	else
	{
		cout <<"no such file" << endl;
	}
	return coef;
}

void geninput(vector<double> &inputsignal , int length){
    //產生input signal
    //set random seed = 1
    srand(5); 

	//generate random signal from -500 to 500
    double randArray[length];
    for(int i=0; i<length; i++){
        randArray[i] = rand()%1000-500;
		// cout << (randArray[i]) << endl;
    }

	//calculate the average power of random number
    double avgpower = 0;
    for(int i=0; i<length; i++){
        avgpower += randArray[i] * randArray[i];
    }
    avgpower/=length;

	//make the average power of random number = 1
    double avgpower2 = 0;
    for(int i=0; i<length; i++){
        double temp = randArray[i]/pow(avgpower, 0.5);
        avgpower2 += temp * temp;
    }
    avgpower2/=length;
    cout << "average power = "<< avgpower2 << endl;
    
	//push back
    for(int i=0; i<length; i++){
        inputsignal.push_back(randArray[i]/pow(avgpower, 0.5));
    }
}

void addnoise(vector<double>& inputsignal){
    double max = 0;
    for(auto a : inputsignal){
        if( fabs(a)>max ) max = fabs(a);
    }
    const double mean = 0.0;
    const double stddev = 0.1;
    std::default_random_engine generator;
    std::normal_distribution<double> dist(mean, stddev);
    // Add Gaussian noise
    for (auto& input : inputsignal) {
        input = input + dist(generator)/100;
    }    
}

double quantize(vector<double>& inputsignal, int wordlength, bool noise = false){
    // normalized
    double max = 0;
    for(auto input : inputsignal){
        if(fabs(input)>max) max = fabs(input);
    }

	//add noise (or not)
    if(noise) addnoise(inputsignal);

    //scaling
    double scale = (pow(2,wordlength-1)-1)/max;
    for(auto& input : inputsignal){
        input *= scale;
    }    
    return scale;
}

void dequantize(vector<double>& inputsignal, double scale){
	//divided by the scale factor to reproduce the signal to original signal range.
    for(auto&input : inputsignal){
        input = input / scale;
    }   
}

void truncate(vector<double>& inputsignal){
    //truncation
    for(auto&input : inputsignal){
        input = floor(input);
    }    
}

void shift(vector<double>& inputsignal, int shift){
	//shift by bits then truncate to perform wordlength operation
    for(auto&input: inputsignal){
        input = input * pow(2,shift);
    }
}

template<typename T>
void savefile(string filename, T& inputsignal){
	ofstream f(filename,ios_base::out);
	for (auto signal: inputsignal){
		f<<signal<<"\n";
	}
	f.close();
}

vector<double> filter(vector<double> inputsignal, double coef[]){
    vector<double> outputsignal;
	double inputbuffer[N];
	double output;
	for(int i=0;i<N;i++){
		inputbuffer[i] = 0;
	}

	for(auto input : inputsignal){
		for(int i=N-1;i>0;i--){
			inputbuffer[i]=inputbuffer[i-1];
		}

		inputbuffer[0] = input;
		output = 0;
		for(int i=0;i<N;i++){
			output += coef[i] * inputbuffer[i];
		}
		outputsignal.push_back(output);
	}
	savefile("./data/outputsignal(floating).txt",outputsignal);
    return outputsignal;
}

vector<double> filter_quantized(vector<double> inputsignal,int wordlength,int MAC_wordlength,double coef[]){
	vector<double> outputsignal;
	vector<double> outputsignal_before_dequantization;
    vector<double> coef_for_quantize;
	for(int i=0;i<N;i++){
		coef_for_quantize.push_back(coef[i]);
	}
	
	double input_scale, coef_scale;
	input_scale = quantize(inputsignal,wordlength,true);
	coef_scale  = quantize(coef_for_quantize,wordlength);
	truncate(inputsignal);
	truncate(coef_for_quantize);

	double inputbuffer[N];
	for(int i=0;i<N;i++){
		inputbuffer[i] = 0;
	}
	
	double output;
	double output_temp;
	int shift_bit = MAC_wordlength - (wordlength+wordlength); //if wordlength = 8 bit, MAC wordlength = 10 bit, we will need to truncate 6 bit (move to right);
    for(auto input : inputsignal){
        for(int i=N-1;i>0;i--){
            inputbuffer[i] = inputbuffer[i-1];
        }
        inputbuffer[0] = input;
		output = 0;
		output_temp = 0;
        for(int i=0;i<N;i++){
            output_temp = coef_for_quantize[i] * inputbuffer[i]; // generate 16 bit output
			output_temp = output_temp*pow(2,shift_bit);// move to right by 6 bit
			output_temp = floor(output_temp);// truncate the signal out from MAC
			output += output_temp;
        }
        outputsignal.push_back(output); // save the result
		truncate(outputsignal); // truncate the 6 bit, only remain 10 bit (make sure the output bit number)
    }
	savefile("./data/coef_quantize.txt",coef_for_quantize);
	savefile("./data/inputsignal_quantize.txt",inputsignal);
	savefile("./data/outputsignal(fixed)before_dequantize.txt",outputsignal);

    //dequantization (compare to no quantization)
	shift(outputsignal, (-1*shift_bit)); // 10 bit shift back to 16 bit, then we can perform dequantization;
    dequantize(outputsignal,input_scale*coef_scale);
	savefile("./data/outputsignal(fixed).txt",outputsignal);
	return outputsignal;
}

double SNR(vector<double> fixed,vector<double> floating){
	double SNR;
	double dividend = 0;
	double divisor = 0;
	for(auto input: floating){
		dividend += pow(input,2);
	}
	for(int i=0;i<signal_length;i++){
		divisor += pow((floating[i]-fixed[i]),2); 
	}
	SNR = 10*log10(dividend/divisor);
    return SNR;
}



int main() {
	int fs = 8000;
	int fcuts1 = 1500;
	int fcuts2 = 2000;
	float delta  = 0.01;
	float A = -20*log10(delta); //attenuation < -40dB
	float beta = 0.5842*(pow(A-21,0.4))+0.07886*(A-21); //21dB <= attenuation <= 50 dB
	int n = ceil((A-7.95)/(2.285*(2000-1500)/(8000/2)*acos(-1))); // (A-7.95)/2.285*transition band(normalize)
	cout << "Filter order:" << (n+1) << endl << "Attenuation:" << A << endl << "beta:" << beta << endl;

	readfile();
	cout << "Read coefficient file" << endl;

	vector<double> inputsignal;
	geninput(inputsignal,1024);
	cout << "Generate input random signal" << endl;
	savefile("./data/inputsignal.txt",inputsignal);
	cout << "Save the input signal in inputsignal.txt" << endl;

    cout << "Start word length test " << endl;
    vector<double> SignaltoNoiseRatio;
    vector<double> wordlength;
	vector<double> floating_point;
	vector<double> fixed_point;
	for(int i=0;i<64;i=i+1){
		floating_point = filter(inputsignal,coef);
		fixed_point = filter_quantized(inputsignal,i,64,coef);
		SignaltoNoiseRatio.push_back(SNR(fixed_point,floating_point));
		wordlength.push_back(i);
	}
	cout << "Save SNR result and wordlength" << endl;
	savefile("./data/SNR(change_wordlength).txt", SignaltoNoiseRatio);
	savefile("./data/wordlength.txt", wordlength);

    cout << "Start MAC word length test " << endl;
	vector<double> MAC_SignaltoNoiseRatio;
	vector<double> MAC_wordlength;
	for(int i=10;i<30;i=i+1){
		floating_point = filter(inputsignal,coef);
		fixed_point = filter_quantized(inputsignal,14,i,coef); // choose word length = 14
		MAC_SignaltoNoiseRatio.push_back(SNR(fixed_point,floating_point));
		MAC_wordlength.push_back(i);
	}
	cout << "Save MAC SNR result and MAC_wordlength" << endl;
	savefile("./data/SNR(change_MAC_wordlength).txt",MAC_SignaltoNoiseRatio);
	savefile("./data/MAC_wordlength.txt",MAC_wordlength);

	floating_point = filter(inputsignal,coef);
	fixed_point = filter_quantized(inputsignal,14,20,coef); // choose word length = 14 and MAC word length = 20
}
