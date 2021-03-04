#version 450
uniform float roll;
uniform writeonly image2D destTex;

layout (local_size_x = 16, local_size_y = 16) in;

layout (std430, binding=8) buffer atoms {vec4 a[];};
layout (std430, binding=9) buffer prevAtoms {vec4 b[];};

void main() 
{
	a[gl_GlobalInvocationID.x + gl_GlobalInvocationID.y*512].x += 10;
	//ivec2 storePos = ivec2(gl_GlobalInvocationID.xy);

	/*
	uint sphereId = floatBitsToUint(gl_in[0].gl_Position.w);
	uint elementId = bitfieldExtract(sphereId,0,8);
	float sphereRadius = elements[elementId].radius*radiusScale;
	float sphereClipRadius = elements[elementId].radius*clipRadiusScale;
	
	gSphereId = sphereId;
	gSpherePosition = gl_in[0].gl_Position;
	gSphereRadius = sphereRadius;

	vec4 c = modelViewMatrix * vec4(gl_in[0].gl_Position.xyz,1.0);
	

	

	float localCoef  = length(vec2(ivec2(gl_LocalInvocationID.xy) - 8) / 8.0);
	float globalCoef = sin(float(gl_WorkGroupID.x + gl_WorkGroupID.y) * 0.1 + roll) * 0.5;

	//if (a[])
	vec3 col;

	vec3 av = a[int(gl_GlobalInvocationID.x + 512*gl_GlobalInvocationID.y)].xyz;
	vec3 bv = b[int(gl_GlobalInvocationID.x + 512*gl_GlobalInvocationID.y)].xyz;

	if (a[int(gl_GlobalInvocationID.x + 512*gl_GlobalInvocationID.y)] == b[int(gl_GlobalInvocationID.x + 512*gl_GlobalInvocationID.y)])
		col = vec3(0.0, 1.0, 0.0);
	else 
		col = a[int(gl_GlobalInvocationID.x + 512*gl_GlobalInvocationID.y)].xyz;
	
	col = a[int(gl_GlobalInvocationID.x + 512*gl_GlobalInvocationID.y)].xyz;
	/*
	else
	{
		col = vec3(1.0,0.0,0.0);//b[0].xyz;
	}
	
	//col = normalize(col);
	//col = (col+1)/2;
	if (av.x == bv.x) 
	{
		col = vec3(0.0, 1.0, 0.0);
	}
	else
	{
		col = vec3(1.0,0.0,0.0);
	}
	imageStore(destTex, storePos, vec4(col, 1.0));//vec4(1.0 - globalCoef * localCoef, 0.0, 0.0, 0.0));
	*/
}
