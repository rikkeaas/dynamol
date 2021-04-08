#version 450
//uniform float roll;
//uniform writeonly image2D destTex;
uniform float timeStep;
uniform float fracTimePassed;

uniform float timeDecay;
uniform vec2 xBounds;
uniform vec2 yBounds;
uniform vec2 zBounds;
uniform bool springForceActive;
uniform float springConst;
uniform float gravityVariable;

uniform int gridResolution;

layout (local_size_x = 1) in;

struct Item
{
  float offset;
  float rand;
  float unused1;
  float unused;
};

struct GridCell
{
	vec4 atoms[16];
	vec4 count;
};


layout (std430, binding=8) buffer atoms {vec4 a[];};
layout (std430, binding=9) buffer prevAtoms {vec4 b[];};
layout (std430, binding=10) buffer originalAtoms {vec4 o[];};
layout (std430, binding=11) buffer gridBuf {GridCell grid[];};
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

void doStep(float deltaTime)
{
	float normX = (b[idx].x - xBounds[0]) / (xBounds[1] + 1 - xBounds[0]);
	float normY = (b[idx].y - yBounds[0]) / (yBounds[1] + 1 - yBounds[0]);
	float normZ = (b[idx].z - zBounds[0]) / (zBounds[1] + 1 - zBounds[0]);

	int idxX = int(normX * gridResolution);
	int idxY = int(normY * gridResolution);
	int idxZ = int(normZ * gridResolution);

	int gridIdx = idxX + gridResolution * (idxY + gridResolution * idxZ);


	vec3 springForce = vec3(0.0);
	if (springForceActive && grid[gridIdx].count.x > 0)
	{
		/*
		vec3 springAxies = b[idx].xyz - grid[gridIdx].atoms[0].xyz;
		float len = length(springAxies);
	
		if (len != 0.0) 
		{
			vec3 springNorm = normalize(springAxies);
			springForce = springNorm * len * springConst;
		}

		*/
		
		vec3 springAxies = b[idx].xyz - o[idx].xyz;
		float len = length(springAxies);
	
		if (len != 0.0) 
		{
			vec3 springNorm = normalize(springAxies);
			springForce = springNorm * len * springConst;
		}
		
	}

	vec3 nextPos = b[idx].xyz + (v[idx].xyz - springForce  - gravityVariable*vec3(0.0, 1.0, 0.0)) * deltaTime;

	if (checkBounds(nextPos.x, xBounds.x, vec3(1.0,0.0,0.0))) nextPos.x = xBounds.x;
	else if (checkBounds(-nextPos.x, -xBounds.y, vec3(-1.0,0.0,0.0))) nextPos.x = xBounds.y;
	else if (checkBounds(nextPos.y, yBounds.x, vec3(0.0,1.0,0.0))) nextPos.y = yBounds.x;
	else if (checkBounds(-nextPos.y, -yBounds.y, vec3(0.0,-1.0,0.0))) nextPos.y = yBounds.y;
	else if (checkBounds(nextPos.z, zBounds.x, vec3(0.0,0.0,1.0))) nextPos.z = zBounds.x;
	else if (checkBounds(-nextPos.z, -zBounds.y, vec3(0.0,0.0,-1.0))) nextPos.z = zBounds.y;


	uint id = floatBitsToUint(b[idx].w);
	uint elementId = bitfieldExtract(id,0,8);
	uint residueId = bitfieldExtract(id,8,8);
	uint chainId = bitfieldExtract(id,16,8);

	uint atomAttributes = elementId | (gridIdx << 8) | (chainId << 16);

	a[idx] = vec4(nextPos, uintBitsToFloat(atomAttributes));
	
	if (fracTimePassed >= 1) 
	{
		v[idx] = v[idx]*timeDecay - vec4(springForce,0.0) - vec4(gravityVariable*vec3(0.0, 1.0, 0.0), 0.0);
	}
}

void main() 
{
	float tempT = timeStep;
	while (tempT > 1) 
	{
		doStep(1.0);
		tempT -= 1.0;
	}
	
	doStep(tempT);
	
	
	
	
	
	
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
