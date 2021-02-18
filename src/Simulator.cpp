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

	prev_vertices = new Buffer();
	prev_vertices->setStorage(timesteps[0], gl::GL_NONE_BIT);
	
}


 std::unique_ptr<globjects::Buffer> Simulator::getVertices()
{
	 return std::unique_ptr<globjects::Buffer>{curr_vertices}; // Creating a unique pointer of the buffer since this is what sphereRenderer expects
}