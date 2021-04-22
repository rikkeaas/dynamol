#version 450
//uniform float roll;
//uniform writeonly image2D destTex;

//uniform bool mr;
uniform vec2 mousePosPixel;
uniform sampler2D positionTexture;

uniform uint maxIdx;
uniform uint selectedAtomId;

uniform mat4 invMVP; 

uniform float timeStep;
uniform float fracTimePassed;

uniform float timeDecay;
uniform vec2 xBounds;
uniform vec2 yBounds;
uniform vec2 zBounds;
uniform bool springForceActive;
uniform float springConst;
uniform float gravityVariable;

uniform bool elephantMode;
uniform vec2 mousePos;

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
	uvec4 count;
	vec4 atoms[300];
};


layout (std430, binding=8) buffer atoms {vec4 a[];};
layout (std430, binding=9) buffer prevAtoms {vec4 b[];};
layout (std430, binding=10) buffer originalAtoms {vec4 o[];};
layout (std140, binding=11) buffer gridBuf {GridCell grid[];};
layout (std140, binding=12) buffer updatedGridBuf {GridCell updatedGrid[];};
layout (std430, binding=13) buffer velocities {vec4 v[];};

uint idx = gl_GlobalInvocationID.x;

vec4 neighbors[300*7];

int oneCell(int x, int y, int z, int curr)
{
	int gridIdx = x + gridResolution * (y + gridResolution * z);
	for (int i = 0; i < grid[gridIdx].count.x; i++)
	{
		neighbors[curr] = grid[gridIdx].atoms[i];
		curr += 1;
	}

	return curr;
}

int getNeighbors(int x, int y, int z) 
{
	
	int curr = 0;

	curr = oneCell(x, y, z, curr);
	if (x > 0) curr = oneCell(x-1, y, z, curr);
	if (x+1 < gridResolution) curr = oneCell(x+1, y, z, curr);
	if (y > 0) curr = oneCell(x, y-1, z, curr);
	if (y+1 < gridResolution) curr = oneCell(x, y+1, z, curr);
	if (z > 0) curr = oneCell(x, y, z-1, curr);
	if (z+1 < gridResolution) curr = oneCell(x, y, z+1, curr);

	return curr; // Corresponds to the length of the neighborhood list. Neighborhood list will contain current atom also..
}


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
	int nbOfNeighbors = getNeighbors(idxX, idxY, idxZ);

	vec3 springForce = vec3(0.0);
	if (springForceActive && idx != 0)
	{
		
		vec3 springAxies = b[idx].xyz - b[idx-1].xyz;
		float len = length(springAxies) - 3;
	
		if (len != 0.0) 
		{
			vec3 springNorm = normalize(springAxies);
			springForce += springNorm * len * springConst;
		}
	}
	if (springForceActive && idx < maxIdx-1)
	{
		vec3 springAxies = b[idx].xyz - b[idx+1].xyz;
		float len = length(springAxies) - 3;
	
		if (len != 0.0) 
		{
			vec3 springNorm = normalize(springAxies);
			springForce += springNorm * len * springConst;
		}
	}

	uint id = floatBitsToUint(b[idx].w);
	uint elementId = bitfieldExtract(id,0,8);
	uint residueId = bitfieldExtract(id,8,8);
	uint chainId = bitfieldExtract(id,16,8);

	if (elephantMode && chainId == selectedAtomId)
	{
		vec4 mp = invMVP*vec4(mousePosPixel,0.0,1.0);
		mp /= mp.w;
		vec3 springAxies = vec3(b[idx].xy - mp.xy, 0.0);
		float len = length(springAxies);
	
		if (len != 0.0) 
		{
			vec3 springNorm = normalize(springAxies);
			springForce += springNorm * len * springConst / 4.0;
		}
	}

	vec3 repulsionForce = vec3(0.0);
	if (elephantMode)
	{
		vec3 repulsionAxis = vec3(b[idx].xy - vec2(305,264), 0.0);
		float dist = distance(b[idx].xyz, vec3(mousePos,0.0));
		if (length(repulsionAxis) < 5.0) // 5.0 is just some random threshold
		{
			repulsionForce = normalize(repulsionAxis) * 200.0 / (dist*dist);
		}
	}


	vec3 nextPos = b[idx].xyz + (v[idx].xyz - springForce - gravityVariable*vec3(0.0, 1.0, 0.0) + repulsionForce) * deltaTime;

	if (checkBounds(nextPos.x, xBounds.x, vec3(1.0,0.0,0.0))) nextPos.x = xBounds.x;
	else if (checkBounds(-nextPos.x, -xBounds.y, vec3(-1.0,0.0,0.0))) nextPos.x = xBounds.y;
	else if (checkBounds(nextPos.y, yBounds.x, vec3(0.0,1.0,0.0))) nextPos.y = yBounds.x;
	else if (checkBounds(-nextPos.y, -yBounds.y, vec3(0.0,-1.0,0.0))) nextPos.y = yBounds.y;
	else if (checkBounds(nextPos.z, zBounds.x, vec3(0.0,0.0,1.0))) nextPos.z = zBounds.x;
	else if (checkBounds(-nextPos.z, -zBounds.y, vec3(0.0,0.0,-1.0))) nextPos.z = zBounds.y;


	

	//uint atomAttributes = elementId | (grid[gridIdx].count.x << 8) | (chainId << 16);
	uint atomAttributes = elementId | (nbOfNeighbors << 8) | (chainId << 16);

	//a[idx] = vec4(nextPos, uintBitsToFloat(atomAttributes));
	a[idx] = vec4(nextPos, b[idx].w);

	if (fracTimePassed >= 1) 
	{
		v[idx] = v[idx]*timeDecay - vec4(springForce,0.0) - vec4(gravityVariable*vec3(0.0, 1.0, 0.0), 0.0) + vec4(repulsionForce,0.0);
	}
}

void main() 
{
	if (elephantMode)
	{
		uint id = floatBitsToUint(a[idx].w);
	
		uint elementId = bitfieldExtract(id,0,8);
		uint residueId = bitfieldExtract(id,8,8);
		uint chainId = bitfieldExtract(id,16,8);

		uint atomAttributes;
		if (selectedAtomId >= 0 && selectedAtomId < maxIdx && chainId == selectedAtomId)
		{
			atomAttributes = elementId | (2 << 8) | (chainId << 16);
		}
		else 
		{
			atomAttributes = elementId | (3 << 8) | (chainId << 16);
		}

		/*
		if (idd == id)
		{
			uint elementId = bitfieldExtract(id,0,8);
			uint residueId = bitfieldExtract(id,8,8);
			uint chainId = bitfieldExtract(id,16,8);
			atomAttributes = elementId | (2 << 8) | (chainId << 16);
		}
		else
		{
			uint elementId = bitfieldExtract(id,0,8);
			uint residueId = bitfieldExtract(id,8,8);
			uint chainId = bitfieldExtract(id,16,8);
			atomAttributes = elementId | (3 << 8) | (chainId << 16);
		}*/

		b[idx] = vec4(b[idx].xyz, uintBitsToFloat(atomAttributes));
		//b[idx] = vec4(b[idx].xyz, atomAttributes);
		
	}



	float tempT = timeStep;
	while (tempT > 1) 
	{
		doStep(1.0);
		tempT -= 1.0;
	}
	
	doStep(tempT);
	
	
	
	float normX = (a[idx].x - xBounds[0]) / (xBounds[1] + 1 - xBounds[0]);
	float normY = (a[idx].y - yBounds[0]) / (yBounds[1] + 1 - yBounds[0]);
	float normZ = (a[idx].z - zBounds[0]) / (zBounds[1] + 1 - zBounds[0]);

	int idxX = int(normX * gridResolution);
	int idxY = int(normY * gridResolution);
	int idxZ = int(normZ * gridResolution);

	int gridIdx = idxX + gridResolution * (idxY + gridResolution * idxZ);

	uint listIdx = atomicAdd(updatedGrid[gridIdx].count.x, 1);
	if (listIdx < updatedGrid[gridIdx].atoms.length())
	{
		updatedGrid[gridIdx].atoms[listIdx] = a[idx];
	}

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
