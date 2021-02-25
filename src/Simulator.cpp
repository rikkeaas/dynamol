#include "Simulator.h"
#include "Viewer.h"
#include "Protein.h"
#include <globjects/State.h>

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
	vertices.push_back(Buffer::create());
	vertices.back()->setStorage(timesteps[0], gl::GL_NONE_BIT);

	auto change = timesteps[0];
	for (int i = 0; i < change.size(); i++)
	{
		change[i] = glm::vec4(change[i].x + (change[i].x < 400 ? -20 : 20), change[i].y, change[i].z, change[i].w);
	}


	vertices.push_back(Buffer::create());
	vertices.back()->setStorage(change, gl::GL_NONE_BIT);

	v_vertices = timesteps[0];
	vertexCount = int(timesteps[0].size());


	auto file = Shader::sourceFromFile("./res/simulator/simulator-cs.glsl");
	auto source = Shader::applyGlobalReplacements(file.get());
	auto shader = globjects::Shader::create(GL_COMPUTE_SHADER, source.get());
	
	globjects::debug() << "AAAAAAAALoading shader file " << source.get() << " ...";

	computeShader->attach(shader.get());

	globjects::debug() << "!!!!!!!!!!!!!!!!" << computeShader->isLinked();

	timeOut = glfwGetTime() + 6;

}

bool Simulator::checkTimeOut() {
	double time = glfwGetTime();
	if (timeOut < time) {
		timeOut = time + 6;
		return true;
	}
	return false;
}


void Simulator::simulate()
{
	auto currentState = State::currentState();

	activeBuffer = (activeBuffer + 1) % 2;
	doStep();

	currentState->apply();
}

void Simulator::doStep()
{
	//Set uniforms

	//Set shaderprogram to use

	//computeShader->link();

	computeShader->use();
	computeShader->dispatchCompute(vertexCount, 0, 0);
	globjects::debug() << "!!!!!!!!!!!!!!!!" << computeShader->isLinked();
	// Bind buffers
	globjects::debug() << "Compute shader?";



	computeShader->release(); 
}


globjects::Buffer* Simulator::getVertices()
{
	return vertices.at(activeBuffer).get();
	//return curr_vertices;
}

void Simulator::draw()
{
	auto vertexBinding = m_vao->binding(0);
	vertexBinding->setAttribute(0);
	vertexBinding->setBuffer(getVertices(), 0, sizeof(vec4));
	vertexBinding->setFormat(4, GL_FLOAT);
	m_vao->enable(0);

	m_vao->bind();
	m_vao->drawArrays(GL_POINTS, 0, vertexCount);
	m_vao->unbind();
}
