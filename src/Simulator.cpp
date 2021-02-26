#include "Simulator.h"
#include "Viewer.h"
#include "Protein.h"
#include <globjects/State.h>

using namespace dynamol;
using namespace gl;
using namespace glm;
using namespace globjects;

Simulator::Simulator(Viewer* viewer) : Renderer(viewer)
{
	m_verticesQuad->setStorage(std::array<vec3, 1>({ vec3(0.0f, 0.0f, 0.0f) }), gl::GL_NONE_BIT);
	auto vertexBindingQuad = m_vaoQuad->binding(0);
	vertexBindingQuad->setBuffer(m_verticesQuad.get(), 0, sizeof(vec3));
	vertexBindingQuad->setFormat(3, GL_FLOAT);
	m_vaoQuad->enable(0);
	m_vaoQuad->unbind();

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


	createShaderProgram("debug", {
			{ GL_VERTEX_SHADER,"./res/sphere/image-vs.glsl" },
			{ GL_GEOMETRY_SHADER,"./res/sphere/image-gs.glsl" },
			{ GL_FRAGMENT_SHADER,"./res/simulator/debug-fs.glsl" },
		});


	createShaderProgram("simulate", {
			{ GL_COMPUTE_SHADER,"./res/simulator/simulator-cs.glsl" }
		});

	timeOut = glfwGetTime() + 6;

	std::vector<unsigned char> filler(512 * 512 * 4, 255);

	m_colorTexture = Texture::create(GL_TEXTURE_2D);
	m_colorTexture->setParameter(GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	m_colorTexture->setParameter(GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	m_colorTexture->setParameter(GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	m_colorTexture->setParameter(GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	m_colorTexture->image2D(0, GL_RGBA32F, 512,512, 0, GL_RGBA, GL_UNSIGNED_BYTE, &filler.front());
	m_colorTexture->bindImageTexture(1, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);

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

	//computeShader->use();
	
	auto simulateProgram = shaderProgram("simulate");
	//simulateProgram->use();

	double time = glfwGetTime();
	simulateProgram->setUniform("roll", float(time));
	simulateProgram->setUniform("destTex", 1);

	simulateProgram->dispatchCompute(512 / 16, 512 / 16, 1);
	globjects::debug() << "!!!" << simulateProgram->isLinked();
	

	simulateProgram->release();
	// Bind buffers

	globjects::debug() << "Compute shader?";

	//computeShader->release(); 

	//glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
	glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT);
}


globjects::Buffer* Simulator::getVertices()
{
	return vertices.at(activeBuffer).get();
}

void Simulator::debug()
{
	auto debugProgram = shaderProgram("debug");

	m_colorTexture->bindActive(0);
	m_vaoQuad->bind();

	debugProgram->setUniform("colorTexture", 0);
	debugProgram->use();
	
	m_vaoQuad->drawArrays(GL_POINTS, 0, 1);
	debugProgram->release();

	m_vaoQuad->unbind();
	m_colorTexture->unbindActive(0);

}

void Simulator::display()
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
