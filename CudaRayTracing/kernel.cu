

//OpenGL
#define GLEW_STATIC
#include <GL\glew.h>
#include <GLFW\glfw3.h>
#include <SOIL.h>
#include "ShaderProgram.h"

//Cuda
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "cuda_gl_interop.h"


#include <stdio.h>
#include <iostream>

using namespace std;













//Quad utilisé pour le rendu de la texture
GLfloat quad[]
{
	-0.5f, -0.5f, 0.0f, 0.0f, 0.0f,
	-0.5f, 0.5f, 0.0f, 0.0f, 1.0f,
	0.5f, 0.5f, 0.0f, 1.0f, 1.0f,

	0.5f, 0.5f, 0.0f, 1.0f, 1.0f,
	0.5f, -0.5f, 0.0f, 1.0f, 0.0f,
	-0.5f, -0.5f, 0.0f, 0.0f, 0.0f
};


cudaError_t addWithCuda(int *c, const int *a, const int *b, unsigned int size);
void key_callback(GLFWwindow* window, int key, int scancode, int action, int mode);


__global__ void fillColor(unsigned char* d_out)
{
	/*int t_idx = threadIdx.x;
	int bx_idx = blockIdx.x;
	int by_idx = blockIdx.y;

	d_out[by_idx * 3 * 1280 + bx_idx * 256 * 3 + t_idx * 3] = 0.5;
	d_out[by_idx * 3 * 1280 + bx_idx * 256 * 3 + t_idx * 3+1] = 0.5;
	d_out[by_idx * 3 * 1280 + bx_idx * 256 * 3 + t_idx * 3+2] = 0.5;*/

	int idx = blockIdx.x * 512*3 + threadIdx.x;
	d_out[idx] = 100;
	d_out[idx + 1] = 100;
	d_out[idx + 2] = 100;
}


int main()
{
	int ResolutionX = 1280;
	int ResolutionY = 720;

	//Initialisation d'OpenGL
	glfwInit();
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

	GLFWwindow* window = glfwCreateWindow(ResolutionX, ResolutionY, "Cuda Lancer de rayon", nullptr, nullptr);
	if (window == nullptr)
	{
		std::cout << "FAILED TO CREATE GLFW WINDOW" << std::endl;
		glfwTerminate();
		return -1;
	}
	glfwMakeContextCurrent(window);


	glewExperimental = GL_TRUE;
	cout << glewInit() << endl;
	if (glewInit() != GLEW_OK)
	{
		std::cout << "FAILED TO INITIALIZE GLEW" << std::endl;

		return -1;
	}

	int width, height;
	glfwGetFramebufferSize(window, &width, &height);
	glViewport(0, 0, width, height);
	//glEnable(GL_DEPTH_TEST);
	//glEnable(GL_BLEND);
	//glEnable(GL_STENCIL_TEST);
	glClearColor(1.0, 0.0, 0.0, 1.0);
	glfwSetKeyCallback(window, key_callback);
	//glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);




	//Création du quad pour le rendu
	//Création du VAO
	GLuint VAO;
	glGenVertexArrays(1, &VAO);
	glBindVertexArray(VAO);
	GLuint quadBufferID;
	glGenBuffers(1,&quadBufferID); //Génération du Buffer
	glBindBuffer(GL_ARRAY_BUFFER, quadBufferID); //Ce buffer est attaché au Vertex Buffer
	glBufferData(GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);
	//Pour les shaders
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), (GLvoid*)0);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), (GLvoid*)(3 * sizeof(GLfloat)));
	glEnableVertexAttribArray(1);
	glBindVertexArray(0);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	//Shaders
	ShaderProgram quadShader("quadVS.vs", "quadFS.fs"); //Shaders associés

	//Création du context Cuda/OpenGL
	cudaError_t cudaStatus;
	cudaStatus = cudaGLSetGLDevice(0); // l'argument est le numéro de la carte graphique. Ca peut être 0, 1 ...
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, " cudaGLSetGLDevice failed!  Do you have a CUDA-capable GPU installed?");
		system("PAUSE");
	}
	

	//Allocation du buffer PBO et lien avec Cuda
	GLuint pixelBufferID;
	cudaGraphicsResource_t cudaResourceBuff;
	glGenBuffers(1, &pixelBufferID);
	glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pixelBufferID);
	glBufferData(GL_PIXEL_UNPACK_BUFFER, ResolutionX*ResolutionY * 3 *sizeof(GLubyte), NULL, GL_DYNAMIC_COPY);
	glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
	cudaStatus = cudaGraphicsGLRegisterBuffer(&cudaResourceBuff, pixelBufferID, cudaGraphicsRegisterFlagsWriteDiscard);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, " cudaGraphicsGLRegisterBuffer failed!");
		cout << cudaGetErrorString(cudaStatus) << endl;
		system("PAUSE");
	}

	//Création de la texture
	GLuint textureID;
	glGenTextures(1, &textureID);
	glBindTexture(GL_TEXTURE_2D, textureID);

	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, ResolutionX, ResolutionY, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
	glGenerateMipmap(GL_TEXTURE_2D);


	//Doit être fait à chaque itération
	while (!glfwWindowShouldClose(window))
	{
		//cout << "Nouvelle boucle" << endl;
		glClearColor(1.0f, 0.1f, 0.1f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);
		

		//Blocage de la ressource pour CUDA
		//Toute tentative d'accès à la ressource par un autre moyen engendra une erreur
		cudaStatus = cudaGraphicsMapResources(1, &cudaResourceBuff, 0);
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, " cudaGraphicsMapResources failed!");
			system("PAUSE");
		}

		glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
		unsigned char* deviceBufferPtr = 0;
		size_t size =0;
		cudaStatus = cudaGraphicsResourceGetMappedPointer((void**)&deviceBufferPtr, &size, cudaResourceBuff);
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, " cudaGraphicsResourceGetMappedPointer failed!");
			cout << cudaGetErrorString(cudaStatus) << endl;
			cout << size << endl;
			system("PAUSE");
		}
		glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
		//Lancement du Kernel
		cout << "Lancement du Kernel" << endl;
		fillColor<<< 1800, 512 >>>(deviceBufferPtr);

		//Deblocage de la ressource
		cout << "Unmap" << endl;
		cudaStatus = cudaGraphicsUnmapResources(1, &cudaResourceBuff, 0);
		if (cudaStatus != cudaSuccess) {
			fprintf(stderr, " cudaGraphicsUnmapResources failed!");
			cout << cudaGetErrorString(cudaStatus) << endl;
			system("PAUSE");
		}

		unsigned char h_in[100];
		cout << sizeof(char) << endl;
		cudaMemcpy(h_in, deviceBufferPtr, 100, cudaMemcpyDeviceToHost);
		for (int i = 0; i < 100; i++)
		{
			cout << h_in[i] << endl;
		}
		system("PAUSE");

		//Transfert du pbo à la texture
		glBindBuffer(GL_PIXEL_UNPACK_BUFFER, pixelBufferID);
		glBindTexture(GL_TEXTURE_2D, textureID);
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, ResolutionX, ResolutionY, GL_RGB, GL_UNSIGNED_BYTE, NULL);

		//Affichage
		quadShader.use();
		glBindVertexArray(VAO);
		glDrawArrays(GL_TRIANGLES, 0, 6);
		glBindVertexArray(0);
		glfwSwapBuffers(window);
		glfwPollEvents();
	}
	glfwTerminate();
    return 0;
}

// Helper function for using CUDA to add vectors in parallel.
//cudaError_t addWithCuda(int *c, const int *a, const int *b, unsigned int size)
//{
//    int *dev_a = 0;
//    int *dev_b = 0;
//    int *dev_c = 0;
//    cudaError_t cudaStatus;
//
//    // Choose which GPU to run on, change this on a multi-GPU system.
//    cudaStatus = cudaSetDevice(0);
//    if (cudaStatus != cudaSuccess) {
//        fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
//        goto Error;
//    }
//
//    // Allocate GPU buffers for three vectors (two input, one output)    .
//    cudaStatus = cudaMalloc((void**)&dev_c, size * sizeof(int));
//    if (cudaStatus != cudaSuccess) {
//        fprintf(stderr, "cudaMalloc failed!");
//        goto Error;
//    }
//
//    cudaStatus = cudaMalloc((void**)&dev_a, size * sizeof(int));
//    if (cudaStatus != cudaSuccess) {
//        fprintf(stderr, "cudaMalloc failed!");
//        goto Error;
//    }
//
//    cudaStatus = cudaMalloc((void**)&dev_b, size * sizeof(int));
//    if (cudaStatus != cudaSuccess) {
//        fprintf(stderr, "cudaMalloc failed!");
//        goto Error;
//    }
//
//    // Copy input vectors from host memory to GPU buffers.
//    cudaStatus = cudaMemcpy(dev_a, a, size * sizeof(int), cudaMemcpyHostToDevice);
//    if (cudaStatus != cudaSuccess) {
//        fprintf(stderr, "cudaMemcpy failed!");
//        goto Error;
//    }
//
//    cudaStatus = cudaMemcpy(dev_b, b, size * sizeof(int), cudaMemcpyHostToDevice);
//    if (cudaStatus != cudaSuccess) {
//        fprintf(stderr, "cudaMemcpy failed!");
//        goto Error;
//    }
//
//    // Launch a kernel on the GPU with one thread for each element.
//    addKernel<<<1, size>>>(dev_c, dev_a, dev_b);
//
//    // Check for any errors launching the kernel
//    cudaStatus = cudaGetLastError();
//    if (cudaStatus != cudaSuccess) {
//        fprintf(stderr, "addKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
//        goto Error;
//    }
//    
//    // cudaDeviceSynchronize waits for the kernel to finish, and returns
//    // any errors encountered during the launch.
//    cudaStatus = cudaDeviceSynchronize();
//    if (cudaStatus != cudaSuccess) {
//        fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching addKernel!\n", cudaStatus);
//        goto Error;
//    }
//
//    // Copy output vector from GPU buffer to host memory.
//    cudaStatus = cudaMemcpy(c, dev_c, size * sizeof(int), cudaMemcpyDeviceToHost);
//    if (cudaStatus != cudaSuccess) {
//        fprintf(stderr, "cudaMemcpy failed!");
//        goto Error;
//    }
//
//Error:
//    cudaFree(dev_c);
//    cudaFree(dev_a);
//    cudaFree(dev_b);
//    
//    return cudaStatus;
//}


//void key_callback(GLFWwindow* window, int key, int scancode, int action, int mode)
//{
//}
//
//void mouse_callback(GLFWwindow* window, double xpos, double ypos)
//{
//
//}
//
//void scroll_callback(GLFWwindow* window, double xoffset, double yoffset)
//{
//
//}

void key_callback(GLFWwindow* window, int key, int scancode, int action, int mode)
{
	if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS)
	{
		glfwSetWindowShouldClose(window, GL_TRUE);
	}
}