#ifndef SHADERPROGRAM_H
#define SHADERPROGRAM_H

#include <GL/glew.h>
#include <iostream>
#include <fstream>

using namespace std;

class ShaderProgram
{
	
public:
	GLuint shaderProgram;
	ShaderProgram(char* vertexShaderPath, char* fragmentShaderPath)
	{
		ifstream vertexShaderFile(vertexShaderPath, ios::in|ios::binary);
		vertexShaderFile.seekg(0, ios::end);

		// read ne fait que lire les bytes. Il ne s'occupe pas de placer un '\0' si important pour marquer la fin de la chaine
		// Il faut le placer sinon le programe continue de lire dans la mémoire tant qu'il ne voit pas de '\0'

		int size = vertexShaderFile.tellg();
		GLchar *vertexShaderSource = new char[size+1];
		vertexShaderFile.seekg(0, ios::beg);
		vertexShaderFile.read(vertexShaderSource, size);
		vertexShaderSource[size] = '\0';


		

		GLuint vertexShader;
		vertexShader = glCreateShader(GL_VERTEX_SHADER);
		glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
		glCompileShader(vertexShader);
		
		GLint success;
		GLchar infoLog[512];
		glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
		if (!success)
		{
			glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
			cout << "Error VS compilation failed " << infoLog << endl;
		}


		//---------------------------

		ifstream fragmentShaderFile(fragmentShaderPath, ios::in|ios::binary);
		fragmentShaderFile.seekg(0, ios::end);
		size = fragmentShaderFile.tellg();
		GLchar* fragmentShaderSource = new char[size+1];
		fragmentShaderFile.seekg(0, ios::beg);
		fragmentShaderFile.read(fragmentShaderSource, size);
		fragmentShaderSource[size] = '\0';
		cout << fragmentShaderSource << endl;

		GLuint fragmentShader;
		fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
		glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
		glCompileShader(fragmentShader);

		glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
		if (!success)
		{
			glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
			cout << "Error FS compilation failed " << infoLog << endl;
		}

		//-------------------------
		shaderProgram = glCreateProgram();
		glAttachShader(shaderProgram, vertexShader);
		glAttachShader(shaderProgram, fragmentShader);
		glLinkProgram(shaderProgram);
		
		glGetProgramiv(shaderProgram, GL_COMPILE_STATUS, &success);
		if (!success)
		{
			glGetShaderInfoLog(shaderProgram, 512, NULL, infoLog);
			cout << "Error PS compilation failed " << infoLog << endl;
		}

		glDeleteShader(vertexShader);
		glDeleteShader(fragmentShader);
	}

	void use()
	{
		glUseProgram(shaderProgram);
	}
};

#endif