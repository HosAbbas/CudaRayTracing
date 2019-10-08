#version 330 core

in vec2 texCoords;
out vec4 FragColor;

uniform sampler2D imageCuda;

void main()
{
vec3 colorpx = texture(imageCuda, texCoords).xyz;
FragColor = vec4(colorpx,1.0f);
//FragColor = vec4(texCoords.x, texCoords.y, 1.0,1.0);
//FragColor = vec4(1.0, 1.0, 1.0,1.0);
}