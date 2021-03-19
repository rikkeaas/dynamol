#version 450
//uniform float roll;
//uniform writeonly image2D destTex;
uniform float timeStep;
uniform float timeDecay;
uniform vec2 xBounds;
uniform vec2 yBounds;
uniform vec2 zBounds;
uniform bool springForceActive;
uniform float springConst;

layout (local_size_x = 1) in;

struct Item
{
  float offset;
  float rand;
  float unused1;
  float unused;
};


layout (std430, binding=8) buffer atoms {vec4 a[];};
layout (std430, binding=9) buffer prevAtoms {vec4 b[];};
layout (std430, binding=10) buffer originalAtoms {vec4 o[];};
//layout (std430, binding=11) buffer axis {float axisBool[];};
layout (std430, binding=12) buffer velocities {vec4 v[];};

uint idx = gl_GlobalInvocationID.x;



bool checkBounds(float pos, float bound, vec3 normal)
{
	if (pos < bound) 
	{
		vec3 ref = reflect(v[idx].xyz, normal); 
		v[idx] = vec4(ref, 0.0);
		return true;
	}
	return false;
}


void main() 
{
	vec3 springForce = vec3(0.0);
	if (springForceActive)
	{
		vec3 springAxies = b[idx].xyz - o[idx].xyz;
		float len = length(springAxies);
	
		if (len != 0.0) 
		{
			vec3 springNorm = normalize(springAxies);
			springForce = springNorm * len * springConst;
		}
	}

	vec3 nextPos = b[idx].xyz + v[idx].xyz - springForce;

	if (checkBounds(nextPos.x, xBounds.x, vec3(1.0,0.0,0.0))) nextPos.x = xBounds.x;
	else if (checkBounds(-nextPos.x, -xBounds.y, vec3(-1.0,0.0,0.0))) nextPos.x = xBounds.y;
	else if (checkBounds(nextPos.y, yBounds.x, vec3(0.0,1.0,0.0))) nextPos.y = yBounds.x;
	else if (checkBounds(-nextPos.y, -yBounds.y, vec3(0.0,-1.0,0.0))) nextPos.y = yBounds.y;
	else if (checkBounds(nextPos.z, zBounds.x, vec3(0.0,0.0,1.0))) nextPos.z = zBounds.x;
	else if (checkBounds(-nextPos.z, -zBounds.y, vec3(0.0,0.0,-1.0))) nextPos.z = zBounds.y;


	a[idx] = vec4(nextPos, b[idx].w);
	v[idx] = v[idx]*timeDecay - vec4(springForce,0.0);
	
	
	
	
	/*
	float time = mod(r[gl_GlobalInvocationID.x/4] + timeStep, 500.0);
	//if (gl_GlobalInvocationID.x % 2 == 0)
	float rad = r[gl_GlobalInvocationID.x/4];

	if (axisBool[gl_GlobalInvocationID.x/4] < 1.0)
	{
		a[gl_GlobalInvocationID.x].x = b[gl_GlobalInvocationID.x].x + rad*cos(3.14*time/5.0);
		a[gl_GlobalInvocationID.x].z = b[gl_GlobalInvocationID.x].z + rad*sin(3.14*time/5.0);
	}
	else if (axisBool[gl_GlobalInvocationID.x/4] < 2.0)
	{
		a[gl_GlobalInvocationID.x].x = b[gl_GlobalInvocationID.x].x + rad*cos(3.14*time/5.0);
		a[gl_GlobalInvocationID.x].y = b[gl_GlobalInvocationID.x].y + rad*sin(3.14*time/5.0);
	}
	else
	{
		a[gl_GlobalInvocationID.x].z = b[gl_GlobalInvocationID.x].z + rad*cos(3.14*time/5.0);
		a[gl_GlobalInvocationID.x].y = b[gl_GlobalInvocationID.x].y + rad*sin(3.14*time/5.0);
	}
	
	

	/*
	float time = mod(r[gl_GlobalInvocationID.x + gl_GlobalInvocationID.y*512] + timeStep, 10.0);
	//if (gl_GlobalInvocationID.x % 2 == 0)
	float rad = r[gl_GlobalInvocationID.x + gl_GlobalInvocationID.y*512];
	
	a[gl_GlobalInvocationID.x + gl_GlobalInvocationID.y*512].x = b[gl_GlobalInvocationID.x + gl_GlobalInvocationID.y*512].x + rad*cos(3.14*time/5.0);
	a[gl_GlobalInvocationID.x + gl_GlobalInvocationID.y*512].z = b[gl_GlobalInvocationID.x + gl_GlobalInvocationID.y*512].z + rad*sin(3.14*time/5.0);
	
	//else
	//{
		//a[gl_GlobalInvocationID.x + gl_GlobalInvocationID.y*512].x = b[gl_GlobalInvocationID.x + gl_GlobalInvocationID.y*512].x + 1*cos(3.14*time/5.0);
		//a[gl_GlobalInvocationID.x + gl_GlobalInvocationID.y*512].y = b[gl_GlobalInvocationID.x + gl_GlobalInvocationID.y*512].y + 1*sin(3.14*time/5.0);
	//}
	// Sende inn tid som uniform
	// Bruke en buffer som center point
	// Skrive til andre buffer slik at posisjonen endrer seg i en sirkel rundt center point.


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
