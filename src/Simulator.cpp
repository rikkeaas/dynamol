#include "Simulator.h"
#include "Viewer.h"
#include "Protein.h"

using namespace dynamol;
using namespace gl;
using namespace glm;
using namespace globjects;

Simulator::Simulator(Viewer* viewer)
{
	auto timesteps = viewer->scene()->protein()->atoms();
	if (timesteps.size() > 1) 
	{
		globjects::debug() << "Disregarding animation for simulation purposes...";
	}
	curr_vertices = new Buffer();
	curr_vertices->setStorage(timesteps[0], gl::GL_NONE_BIT);

	auto change = timesteps[0];
	for (int i = 0; i < change.size(); i++)
	{
		change[i] = glm::vec4(change[i].x*1.5, change[i].y*1.5f, change[i].z*1.5f, change[i].w);
	}


	prev_vertices = new Buffer();
	prev_vertices->setStorage(change, gl::GL_NONE_BIT);

	timeOut = glfwGetTime() + 10;
}

bool Simulator::checkTimeOut() {
	double time = glfwGetTime();
	if (timeOut < time) {
		timeOut = time + 10;
		return true;
	}
	return false;
}


void Simulator::simulate()
{
	// Letting the current vertices become the previous ones (by changing the pointers, not moving the memory)
	globjects::Buffer* tempPointer = curr_vertices;
	curr_vertices = prev_vertices;
	prev_vertices = tempPointer;


}



globjects::Buffer* Simulator::getVertices()
{
	 return curr_vertices; // Creating a unique pointer of the buffer since this is what sphereRenderer expects
}