#include "Simulator.h"
#include "Viewer.h"
#include "Protein.h"
#include <globjects/State.h>

#include <imgui.h>

using namespace dynamol;
using namespace gl;
using namespace glm;
using namespace globjects;

Simulator::Simulator(Viewer* viewer) : Renderer(viewer)
{
	m_viewer = viewer;
	m_explosion = new Explosion(viewer);

	/*
	m_verticesQuad->setStorage(std::array<vec3, 1>({ vec3(0.0f, 0.0f, 0.0f) }), gl::GL_NONE_BIT);
	auto vertexBindingQuad = m_vaoQuad->binding(0);
	vertexBindingQuad->setBuffer(m_verticesQuad.get(), 0, sizeof(vec3));
	vertexBindingQuad->setFormat(3, GL_FLOAT);
	m_vaoQuad->enable(0);
	m_vaoQuad->unbind();
	*/

	auto timesteps = viewer->scene()->protein()->atoms();
	if (timesteps.size() > 1)
	{
		globjects::debug() << "Disregarding animation for simulation purposes...";
	}
	m_vertices.push_back(Buffer::create());
	m_vertices.back()->setData(timesteps[0], GL_STREAM_DRAW); // stream draw means changing values in buffer often, static draw means changing only once

	m_vertices.push_back(Buffer::create());
	m_vertices.back()->setData(timesteps[0], GL_STREAM_DRAW);

	m_vertexCount = timesteps[0].size();

	// Creating some random time offsets to make dummy simulation nicer
	std::vector<float> randomOffsets;
	std::vector<float> randomBools;
	srand((unsigned int)time(NULL));
	for (float i = 0; i < m_vertexCount; i++)
	{
		randomOffsets.push_back(1.0 + static_cast <float> (rand()) / (static_cast <float> (RAND_MAX / 10.0)));
		randomBools.push_back(static_cast <float> (rand()) / (static_cast <float> (RAND_MAX / 3.0)));
	}

	m_randomness = Buffer::create();
	m_randomness->setStorage(randomOffsets, gl::GL_NONE_BIT);

	m_originalPos = Buffer::create();
	m_originalPos->setStorage(timesteps[0], gl::GL_NONE_BIT);

	m_shouldUseZ = Buffer::create();
	m_shouldUseZ->setStorage(randomBools, gl::GL_NONE_BIT);


	createShaderProgram("debug", {
			{ GL_VERTEX_SHADER,"./res/sphere/image-vs.glsl" },
			{ GL_GEOMETRY_SHADER,"./res/sphere/image-gs.glsl" },
			{ GL_FRAGMENT_SHADER,"./res/simulator/debug-fs.glsl" },
		});


	createShaderProgram("simulate", {
			{ GL_COMPUTE_SHADER,"./res/simulator/simulator-cs.glsl" }
		});

	m_timeOut = glfwGetTime() + 3;

	/*
	std::vector<unsigned char> filler(512 * 512 * 4, 255);

	m_colorTexture = Texture::create(GL_TEXTURE_2D);
	m_colorTexture->setParameter(GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	m_colorTexture->setParameter(GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	m_colorTexture->setParameter(GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	m_colorTexture->setParameter(GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	m_colorTexture->image2D(0, GL_RGBA32F, 512,512, 0, GL_RGBA, GL_UNSIGNED_BYTE, &filler.front());
	m_colorTexture->bindImageTexture(1, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);
	*/

	m_timeStep = 0.0;
}

bool Simulator::checkTimeOut() {
	double time = glfwGetTime();
	if (m_timeOut < time) {
		m_timeOut = time + 3;
		return true;
	}
	return false;
}


void Simulator::simulate()
{
	auto currentState = State::currentState();

	m_activeBuffer = (m_activeBuffer + 1) % 2;
	doStep();

	currentState->apply();
}

void Simulator::doStep()
{
	m_explosion->display();
	if (ImGui::BeginMenu("Simulator"))
	{
		ImGui::Checkbox("Dummy simulation", &dummyAnimation);
		ImGui::DragFloatRange2("X bounds: ", &m_xbounds.x, &m_xbounds.y, 1.0, -100.0, 450.0);
		ImGui::DragFloatRange2("Y bounds: ", &m_ybounds.x, &m_ybounds.y, 1.0, -100.0, 450.0);
		ImGui::DragFloatRange2("Z bounds: ", &m_zbounds.x, &m_zbounds.y, 1.0, -100.0, 450.0);

		ImGui::Checkbox("Spring force: ", &m_springActivated);
		if (m_springActivated)
			ImGui::SliderFloat("Spring constant: ", &m_springConst, 0.0, 1.0);

		ImGui::Checkbox("Gravity: ", &m_gravityActivated);
		if (m_gravityActivated)
			ImGui::SliderFloat("Gravity multiplier: ", &m_gravity, 0.0, 5.0);
		else
			m_gravity = 0.0;

		if (ImGui::Button("Reset atom positions"))
		{
			auto timesteps = m_viewer->scene()->protein()->atoms();
			for (int i = 0; i < m_vertices.size(); i++)
			{
				m_vertices[i]->setData(timesteps[0], GL_STREAM_DRAW);
			}
		}

		ImGui::EndMenu();
	}

	if (dummyAnimation)
	{
		auto simulateProgram = shaderProgram("simulate");

		m_vertices.at(m_activeBuffer)->bindBase(GL_SHADER_STORAGE_BUFFER, 8);
		m_vertices.at((m_activeBuffer + 1) % 2)->bindBase(GL_SHADER_STORAGE_BUFFER, 9);
		m_originalPos->bindBase(GL_SHADER_STORAGE_BUFFER, 10);
		//m_randomness->bindBase(GL_SHADER_STORAGE_BUFFER, 10);
		//m_shouldUseZ->bindBase(GL_SHADER_STORAGE_BUFFER, 11);
		m_explosion->bindVelocity();

		if (m_timeStep >= 500.0)
		{
			m_timeStep = 0.0;
		}
		else
		{
			m_timeStep += 0.1;
		}

		simulateProgram->setUniform("timeStep", m_timeStep);
		simulateProgram->setUniform("timeDecay", m_explosion->getTimeDecay());
		simulateProgram->setUniform("xBounds", m_xbounds);
		simulateProgram->setUniform("yBounds", m_ybounds);
		simulateProgram->setUniform("zBounds", m_zbounds);
		simulateProgram->setUniform("springForceActive", m_springActivated);
		simulateProgram->setUniform("springConst", m_springConst);
		simulateProgram->setUniform("gravityVariable", m_gravity);

		simulateProgram->dispatchCompute(m_vertexCount, 1, 1);
		simulateProgram->release();

		glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
		//glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT);

		m_explosion->releaseVelocity();
		m_originalPos->unbind(GL_SHADER_STORAGE_BUFFER);
		//m_shouldUseZ->unbind(GL_SHADER_STORAGE_BUFFER);
		//m_randomness->unbind(GL_SHADER_STORAGE_BUFFER);
		m_vertices.at(m_activeBuffer)->unbind(GL_SHADER_STORAGE_BUFFER);
		m_vertices.at((m_activeBuffer + 1) % 2)->unbind(GL_SHADER_STORAGE_BUFFER);
	}
}


globjects::Buffer* Simulator::getVertices()
{
	return m_vertices.at(m_activeBuffer).get();
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
	m_vao->drawArrays(GL_POINTS, 0, m_vertexCount);
	m_vao->unbind();
}
