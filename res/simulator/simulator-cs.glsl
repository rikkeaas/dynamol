#version 450

uniform uint maxIdx;
uniform uint selectedAtomId;
uniform vec3 selectedAtomPos;

uniform mat4 MVP;
uniform mat4 invMVP;
uniform mat4 invMV;

uniform float timeStep;
uniform float fracTimePassed;

uniform float timeDecay;

uniform vec2 xBounds;
uniform vec2 yBounds;
uniform vec2 zBounds;

uniform bool springForceActive;
uniform float springConst;

uniform float gravityVariable;

uniform bool springToOriginalPos;
uniform float springToOriginalPosConst;

uniform bool mouseAttraction;
uniform float mouseAttractionSpringConst;
uniform vec2 mousePos;

uniform bool updateOriginalPos;

uniform float repulsionStrength;
uniform int gridResolution;

uniform bool viewDistortion = true;
uniform float viewDistortionStrength = 2;
uniform float distortionDistCutOff;

uniform float stretchForceStrength;
uniform float xStretch;
uniform float yStretch;
uniform float zStretch;

layout (local_size_x = 1) in;

struct Element
{
	vec3 color;
	float radius;
};

struct GridCell
{
	uvec4 count;
	vec4 atoms[300];
};

layout (std140, binding=7) uniform elementBlock { Element elements[32]; };
layout (std430, binding=8) buffer atoms {vec4 a[];};
layout (std430, binding=9) buffer prevAtoms {vec4 b[];};
layout (std430, binding=10) buffer originalAtoms {vec4 o[];};
layout (std140, binding=11) buffer gridBuf {GridCell grid[];};
layout (std140, binding=12) buffer updatedGridBuf {GridCell updatedGrid[];};
layout (std430, binding=13) buffer velocities {vec4 v[];};

uint idx = gl_GlobalInvocationID.x;
uint id = floatBitsToUint(b[idx].w);
uint elementId = bitfieldExtract(id,0,8);
uint residueId = bitfieldExtract(id,8,8);
uint chainId = bitfieldExtract(id,16,8);

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


bool checkAtomIntersection(vec4 other, float rad)
{
	uint otherId = floatBitsToUint(other.w);
	uint otherElementId = bitfieldExtract(otherId,0,8);
	uint otherResidueId = bitfieldExtract(otherId,8,8);
	uint otherChainId = bitfieldExtract(otherId,16,8);

	// Atom 'other' is the same as the current atom, don't want to intersect with ourselves
	if (otherChainId == chainId) return false;

	float otherRad = elements[otherElementId].radius;

	// Intersection if distance between the two centers is less than the sum of the Van der Waals sphere radii
	return (distance(other.xyz, b[idx].xyz) < (otherRad + rad));
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
	// Spring force between neighbors
	// --------------------------------------------------------------------
	vec3 neighborSpringForce = vec3(0.0);
	if (springForceActive && idx != 0)
	{
		
		vec3 springAxies = b[idx].xyz - b[idx-1].xyz;
		float len = length(springAxies) - 3;
	
		if (len != 0.0) 
		{
			vec3 springNorm = normalize(springAxies);
			neighborSpringForce += springNorm * len * springConst;
		}
	}
	if (springForceActive && idx < maxIdx-1)
	{
		vec3 springAxies = b[idx].xyz - b[idx+1].xyz;
		float len = length(springAxies) - 3;
	
		if (len != 0.0) 
		{
			vec3 springNorm = normalize(springAxies);
			neighborSpringForce += springNorm * len * springConst;
		}
	}
	// --------------------------------------------------------------------

	// Spring force towards mouse pointer
	// --------------------------------------------------------------------
	vec3 mouseSpringForce = vec3(0.0);
	if (mouseAttraction && chainId == selectedAtomId)
	{
		vec4 screenAtom = MVP * vec4(b[idx].xyz,1.0);
		vec2 screenAtomXY = screenAtom.xy / screenAtom.w;
		vec3 springAxisScreen = vec3(screenAtomXY - mousePos,0.0);

		vec3 springAxies = (invMVP * vec4(springAxisScreen,0.0)).xyz;
		
		float len = length(springAxies);
	
		if (len != 0.0) 
		{
			vec3 springNorm = normalize(springAxies);
			mouseSpringForce = springNorm * len * mouseAttractionSpringConst;
		}
	}
	// --------------------------------------------------------------------

	// Spring force to atoms original position
	// --------------------------------------------------------------------
	vec3 returnSpringForce = vec3(0.0);
	if (springToOriginalPos)
	{
		vec3 springAxies = b[idx].xyz - o[idx].xyz;
		float len = length(springAxies);
	
		if (len != 0.0) 
		{
			vec3 springNorm = normalize(springAxies);
			returnSpringForce = springNorm * len * springToOriginalPosConst;
		}
	}
	// --------------------------------------------------------------------

	// Repulsion force between neighboring atoms based on grid
	// --------------------------------------------------------------------
	vec3 repulsionForce = vec3(0.0);

	float normX = (b[idx].x - xBounds[0]) / (xBounds[1] + 1 - xBounds[0]);
	float normY = (b[idx].y - yBounds[0]) / (yBounds[1] + 1 - yBounds[0]);
	float normZ = (b[idx].z - zBounds[0]) / (zBounds[1] + 1 - zBounds[0]);

	int idxX = int(normX * gridResolution);
	int idxY = int(normY * gridResolution);
	int idxZ = int(normZ * gridResolution);

	int gridIdx = idxX + gridResolution * (idxY + gridResolution * idxZ);
	
	GridCell cell = grid[gridIdx];
	float rad = elements[elementId].radius;
	for (int i = 0; i < cell.count.x; i++)
	{
		if (!checkAtomIntersection(cell.atoms[i], rad)) continue;

		vec3 fDir = normalize(b[idx].xyz - cell.atoms[i].xyz);
		repulsionForce += repulsionStrength * fDir / pow((distance(b[idx].xyz, cell.atoms[i].xyz)),2);
	}
	// --------------------------------------------------------------------

	// Stretching
	// --------------------------------------------------------------------
	vec3 stretchForce = vec3(0.0);

	if (stretchForceStrength > 0.0)
	{
		if (xStretch != 0.0)
		{
			vec3 stretchedPos;
			vec3 springAxies;
			float scaleFactor;
			float centerX = (xBounds.x + xBounds.y)/2;
			if (o[idx].x < centerX)
			{
				stretchedPos = o[idx].xyz - vec3(xStretch, 0.0, 0.0);
				springAxies  = vec3(1.0,0.0,0.0);
				scaleFactor = centerX - o[idx].x;
			}
			else
			{
				stretchedPos = o[idx].xyz + vec3(xStretch,0.0,0.0);
				springAxies = vec3(-1.0,0.0,0.0);
				scaleFactor = o[idx].x- centerX;
			}
		
			float len = distance(b[idx].xyz, stretchedPos);
	
			if (len != 0.0) 
			{
				stretchForce = springAxies * stretchForceStrength * len * scaleFactor;
			}
		}
		if (yStretch != 0.0)
		{
			vec3 stretchedPos;
			vec3 springAxies;
			float scaleFactor;
			float centerY = (yBounds.x + yBounds.y)/2;
			if (o[idx].y < centerY)
			{
				stretchedPos = o[idx].xyz - vec3(0.0, yStretch, 0.0);
				springAxies  = vec3(0.0,1.0,0.0);
				scaleFactor = centerY - o[idx].y;
			}
			else
			{
				stretchedPos = o[idx].xyz + vec3(0.0, yStretch, 0.0);
				springAxies = vec3(0.0,-1.0,0.0);
				scaleFactor = o[idx].y - centerY;
			}
		
			float len = distance(b[idx].xyz, stretchedPos);
	
			if (len != 0.0) 
			{
				stretchForce += springAxies * stretchForceStrength * len * scaleFactor;
			}
		}
		if (zStretch != 0.0)
		{
			vec3 stretchedPos;
			vec3 springAxies;
			float scaleFactor;
			float centerZ = (zBounds.x + zBounds.y)/2;
			if (o[idx].z < centerZ)
			{
				stretchedPos = o[idx].xyz - vec3(0.0, 0.0, zStretch);
				springAxies  = vec3(0.0,0.0,1.0);
				scaleFactor = centerZ - o[idx].z;
			}
			else
			{
				stretchedPos = o[idx].xyz + vec3(0.0, 0.0, zStretch);
				springAxies = vec3(0.0,0.0,-1.0);
				scaleFactor = o[idx].z - centerZ;
			}
		
			float len = distance(b[idx].xyz, stretchedPos);
	
			if (len != 0.0) 
			{
				stretchForce += springAxies * stretchForceStrength * len * scaleFactor;
			}
		}
	}
	// --------------------------------------------------------------------

	// Viewing distortion
	// --------------------------------------------------------------------
	vec3 viewDistortionForce = vec3(0.0);
	if (viewDistortion && chainId != selectedAtomId && selectedAtomId < maxIdx)
	{
		vec4 globalCam = invMV * vec4(0.0,0.0,1.0,1.0);
		globalCam = globalCam / globalCam.w;
		
		if (distance(globalCam.xyz, selectedAtomPos) >= distance(globalCam.xyz, b[idx].xyz))
		{
			vec3 viewSelectedAxis = selectedAtomPos - globalCam.xyz;

			vec3 viewThisVector = b[idx].xyz - globalCam.xyz;

			vec3 planeNormal = cross(viewSelectedAxis, viewThisVector);
			vec3 distortionAxis = normalize(cross(planeNormal, viewSelectedAxis));

			float distortionDist = dot(viewThisVector, distortionAxis);

			if (distortionDist <= distortionDistCutOff)
			{
				viewDistortionForce = viewDistortionStrength * distortionAxis / pow(distortionDist,2);
				mouseSpringForce = vec3(0.0);
				returnSpringForce = vec3(0.0);
				repulsionForce = vec3(0.0);
				stretchForce = vec3(0.0);
			}
		}
	}
	// --------------------------------------------------------------------

	vec3 nextPos;
	if (viewDistortion && chainId == selectedAtomId)
	{
		nextPos = selectedAtomPos;
	}
	else 
	{
		vec3 springForce = neighborSpringForce + mouseSpringForce + returnSpringForce;
		nextPos = b[idx].xyz + (v[idx].xyz - springForce - gravityVariable*vec3(0.0, 1.0, 0.0) + repulsionForce + viewDistortionForce - stretchForce) * deltaTime;
	}
	if (checkBounds(nextPos.x, xBounds.x, vec3(1.0,0.0,0.0))) nextPos.x = xBounds.x;
	else if (checkBounds(-nextPos.x, -xBounds.y, vec3(-1.0,0.0,0.0))) nextPos.x = xBounds.y;
	else if (checkBounds(nextPos.y, yBounds.x, vec3(0.0,1.0,0.0))) nextPos.y = yBounds.x;
	else if (checkBounds(-nextPos.y, -yBounds.y, vec3(0.0,-1.0,0.0))) nextPos.y = yBounds.y;
	else if (checkBounds(nextPos.z, zBounds.x, vec3(0.0,0.0,1.0))) nextPos.z = zBounds.x;
	else if (checkBounds(-nextPos.z, -zBounds.y, vec3(0.0,0.0,-1.0))) nextPos.z = zBounds.y;


	//uint atomAttributes = elementId | (residueId << 8) | (chainId << 16);

	//a[idx] = vec4(nextPos, uintBitsToFloat(atomAttributes));
	a[idx] = vec4(nextPos, b[idx].w);

	if (fracTimePassed >= 1) 
	{
		vec3 springForce = neighborSpringForce + mouseSpringForce + returnSpringForce;
		v[idx] = v[idx]*timeDecay - vec4(springForce,0.0) - vec4(gravityVariable*vec3(0.0, 1.0, 0.0), 0.0) + vec4(repulsionForce,0.0);
	}
}

void main() 
{
	if (mouseAttraction || viewDistortion)
	{
		uint atomAttributes;
		uint selectedColor = mouseAttraction ? 2 : 4;
		uint restColor = mouseAttraction ? 3 : 5;
		if (selectedAtomId >= 0 && selectedAtomId < maxIdx && chainId == selectedAtomId)
		{
			atomAttributes = elementId | (selectedColor << 8) | (chainId << 16);
		}
		else 
		{
			atomAttributes = elementId | (restColor << 8) | (chainId << 16);
		}

		b[idx] = vec4(b[idx].xyz, uintBitsToFloat(atomAttributes));
		
	}


	if (updateOriginalPos && chainId == selectedAtomId) 
	{
		o[idx] = b[idx];
	}


	float tempT = timeStep;
	while (tempT > 1) 
	{
		doStep(1.0);
		tempT -= 1.0;
	}
	
	doStep(tempT);
	
	
	if (repulsionStrength == 0.0) return; 

	float radius = elements[elementId].radius;
	int[27] alreadyVisited;
	int alreadyVisitedIdx = 0;
	for (int x = -1; x <= 1; x++)
	{
		for (int y = -1; y <= 1; y++)
		{
			for (int z = -1; z <= 1; z++)
			{
				float normX = ((a[idx].x + x*radius) - xBounds[0]) / (xBounds[1] + 1 - xBounds[0]);
				float normY = ((a[idx].y + y*radius) - yBounds[0]) / (yBounds[1] + 1 - yBounds[0]);
				float normZ = ((a[idx].z + z*radius) - zBounds[0]) / (zBounds[1] + 1 - zBounds[0]);

				if (normX < 0.0 || normX >= 1.0 || normY < 0.0 || normY >= 1.0 || normZ  < 0.0 || normZ >= 1.0)
				{
					continue;
				}

				int idxX = int(normX * gridResolution);
				int idxY = int(normY * gridResolution);
				int idxZ = int(normZ * gridResolution);

				int gridIdx = idxX + gridResolution * (idxY + gridResolution * idxZ);

				bool visited = false;
				for (int i = 0; i < alreadyVisitedIdx; i++)
				{
					if (gridIdx == alreadyVisited[i])
					{
						visited = true;
						break;
					}
				}

				if (!visited)
				{
					alreadyVisited[alreadyVisitedIdx++] = gridIdx;
					uint listIdx = atomicAdd(updatedGrid[gridIdx].count.x, 1);
					if (listIdx < updatedGrid[gridIdx].atoms.length())
					{
						updatedGrid[gridIdx].atoms[listIdx] = a[idx];
					}
				}
			}
		}
	}
	
	
}
