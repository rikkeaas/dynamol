#version 450

uniform sampler2D colorTexture;
in vec4 gFragmentPosition;
out vec4 fragColor;

void main()
{
	vec2 coords = (gFragmentPosition.xy+vec2(1.0))*0.5;
	vec4 color = texture(colorTexture,coords);
	fragColor = color;
}