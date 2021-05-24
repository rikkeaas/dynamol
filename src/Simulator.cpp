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

	m_prevTime = std::chrono::high_resolution_clock::now();

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


	vec3 minbounds = viewer->scene()->protein()->minimumBounds();
	vec3 maxounds = viewer->scene()->protein()->maximumBounds();

	m_xbounds = vec2(minbounds.x- 50, maxounds.x + 50);
	m_ybounds = vec2(minbounds.y- 50, maxounds.y + 50);
	m_zbounds = vec2(minbounds.z - 30, maxounds.z + 30);
	
	m_originalPos = Buffer::create();
	m_originalPos->setData(timesteps[0], GL_STATIC_DRAW);

	m_timeStep = 0.0;

	createShaderProgram("debug", {
			{ GL_VERTEX_SHADER,"./res/sphere/image-vs.glsl" },
			{ GL_GEOMETRY_SHADER,"./res/sphere/image-gs.glsl" },
			{ GL_FRAGMENT_SHADER,"./res/simulator/debug-fs.glsl" },
		});


	createShaderProgram("simulate", {
			{ GL_COMPUTE_SHADER,"./res/simulator/simulator-cs.glsl" }
		});


	m_emptyNeighborhoodList.resize(m_gridResolution * m_gridResolution * m_gridResolution);

	m_grids.push_back(Buffer::create());
	m_grids.back()->setData(m_emptyNeighborhoodList, GL_STREAM_DRAW);

	m_grids.push_back(Buffer::create());
	m_grids.back()->setData(m_emptyNeighborhoodList, GL_STREAM_DRAW);
	//m_gridBuffer->setData(m_neighborhoodList, GL_STREAM_DRAW);

	/*
	m_verticesQuad->setStorage(std::array<vec3, 1>({ vec3(0.0f, 0.0f, 0.0f) }), gl::GL_NONE_BIT);
	auto vertexBindingQuad = m_vaoQuad->binding(0);
	vertexBindingQuad->setBuffer(m_verticesQuad.get(), 0, sizeof(vec3));
	vertexBindingQuad->setFormat(3, GL_FLOAT);
	m_vaoQuad->enable(0);
	m_vaoQuad->unbind();
	*/


	// Creating some random time offsets to make dummy simulation nicer
	/*
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


	m_shouldUseZ = Buffer::create();
	m_shouldUseZ->setStorage(randomBools, gl::GL_NONE_BIT);
	*/

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

}




void Simulator::simulate()
{
	auto currentState = State::currentState();

	m_activeBuffer = (m_activeBuffer + 1) % 2;
	m_activeGridBuffer = (m_activeGridBuffer + 1) % 2;
	doStep();

	currentState->apply();
}

void Simulator::doStep()
{
	if (ImGui::Begin("Simulator"))
	{
		ImGui::Checkbox("Dummy simulation", &dummyAnimation);

		ImGui::SliderInt("Grid resolution", &m_gridResolution, 1, 20);
		ImGui::SliderFloat("Repulsion force strength", &m_repulsionForce, 0.0, 2.0);
		ImGui::SliderFloat("Simulation speed", &m_speedMultiplier, 0.0f, 200.0f);
		ImGui::SliderFloat("Decay of velocity with time: ", &m_timeDecay, 0.9, 1.1);
		ImGui::DragFloatRange2("X bounds: ", &m_xbounds.x, &m_xbounds.y, 1.0, -100, 450.0);
		ImGui::DragFloatRange2("Y bounds: ", &m_ybounds.x, &m_ybounds.y, 1.0, -100.0, 450.0);
		ImGui::DragFloatRange2("Z bounds: ", &m_zbounds.x, &m_zbounds.y, 1.0, -100.0, 450.0);

		ImGui::Checkbox("Mouse interaction: ", &m_mouseAttraction);
		if (m_mouseAttraction)
			ImGui::SliderFloat("Mouse attraction spring contant: ", &m_mouseSpringConst, 0.0, 1.0);
		
		ImGui::Checkbox("Spring force to original positions: ", &m_originalPosSpringForce);
		if (m_originalPosSpringForce)
			ImGui::SliderFloat("Original position spring constant: ", &m_returnSpringConst, 0.0, 1.0);
		
		ImGui::Checkbox("Spring force: ", &m_springActivated);
		if (m_springActivated)
			ImGui::SliderFloat("Spring constant: ", &m_springConst, 0.0, 1.0);

		ImGui::Checkbox("View distortion: ", &m_viewDistortion);
		if (m_viewDistortion)
		{
			ImGui::SliderFloat("View Distortion Strength: ", &m_viewDistortionStrength, 0.0, 3.0);
			ImGui::SliderFloat("Distortion Distance Cut Off: ", &m_distortionDistCutOff, 0.0, 15.0);
			if (ImGui::Button("Remove selection"))
			{
				selectedAtomId = m_vertexCount;
			}
		}

		ImGui::Checkbox("Gravity: ", &m_gravityActivated);
		if (m_gravityActivated)
			ImGui::SliderFloat("Gravity multiplier: ", &m_gravity, 0.0, 5.0);
		else
			m_gravity = 0.0;

		ImGui::SliderFloat("Strength of stretch force", &m_stretchStrength, 0.0, 2.0);
		ImGui::SliderFloat("Stretch along x-axis", &m_xStretch, 0.0, 100.0);
		ImGui::SliderFloat("Stretch along y-axis", &m_yStretch, 0.0, 100.0);
		ImGui::SliderFloat("Stretch along z-axis", &m_zStretch, 0.0, 100.0);

		if (ImGui::Button("Reset atom positions"))
		{
			auto timesteps = m_viewer->scene()->protein()->atoms();
			for (int i = 0; i < m_vertices.size(); i++)
			{
				m_vertices[i]->setData(timesteps[0], GL_STREAM_DRAW);
			}
			m_originalPos->setData(timesteps[0], GL_STATIC_DRAW);
		}

		ImGui::EndMenu();
	}
	m_explosion->display();

	if (dummyAnimation)
	{
		vec2 mousePos = vec2(0.0);

		if (m_mouseAttraction || m_viewDistortion)
		{	
			glfwGetCursorPos(m_viewer->window(), &mouseX, &mouseY);
			mousePos = vec2(2.0f * float(mouseX) / float(m_viewer->viewportSize().x) - 1.0f, -2.0f * float(mouseY) / float(m_viewer->viewportSize().y) + 1.0f);
			
			if (glfwGetMouseButton(m_viewer->window(), GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS && !m_mousePress)
			{
				m_mousePress = true;
			}

			else if (glfwGetMouseButton(m_viewer->window(), GLFW_MOUSE_BUTTON_LEFT) == GLFW_RELEASE && !m_viewDistortion && m_mousePress)
			{
				vec4 data;
				glReadBuffer(gl::GLenum::GL_COLOR_ATTACHMENT0);
				glReadPixels(mouseX, m_viewer->viewportSize().y - mouseY, 1, 1, GL_RGBA, GL_FLOAT, &data);
				uint id = floatBitsToUint(data.w);
				uint elementId = bitfieldExtract(id, 0, 8);
				uint residueId = bitfieldExtract(id, 8, 8);
				uint newSelectedAtomId = bitfieldExtract(id, 16, 8);
				selectedAtomId = newSelectedAtomId == selectedAtomId ? m_vertexCount : newSelectedAtomId;
				m_mousePress = false;
			}
			else if (glfwGetMouseButton(m_viewer->window(), GLFW_MOUSE_BUTTON_LEFT) == GLFW_RELEASE && m_viewDistortion && m_mousePress && selectedAtomId >= m_vertexCount)
			{
				vec4 data;
				glReadBuffer(gl::GLenum::GL_COLOR_ATTACHMENT0);
				glReadPixels(mouseX, m_viewer->viewportSize().y - mouseY, 1, 1, GL_RGBA, GL_FLOAT, &data);
				uint id = floatBitsToUint(data.w);
				uint elementId = bitfieldExtract(id, 0, 8);
				uint residueId = bitfieldExtract(id, 8, 8);
				uint newSelectedAtomId = bitfieldExtract(id, 16, 8);
				
				if (newSelectedAtomId < m_vertexCount)
				{
					selectedAtomId = newSelectedAtomId;
					glReadBuffer(gl::GLenum::GL_COLOR_ATTACHMENT1);
					glReadPixels(mouseX, m_viewer->viewportSize().y - mouseY, 1, 1, GL_RGBA, GL_FLOAT, &data);
					selectedAtomPos = vec3(data);
				}
				m_mousePress = false;
			}

			if (glfwGetKey(m_viewer->window(), GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS || glfwGetKey(m_viewer->window(), GLFW_KEY_RIGHT_SHIFT) == GLFW_PRESS)
			{
				m_updateOriginalPosition = true;
			}
		}

		auto simulateProgram = shaderProgram("simulate");

		m_vertices.at(m_activeBuffer)->bindBase(GL_SHADER_STORAGE_BUFFER, 8);
		m_vertices.at((m_activeBuffer + 1) % 2)->bindBase(GL_SHADER_STORAGE_BUFFER, 9);
		m_originalPos->bindBase(GL_SHADER_STORAGE_BUFFER, 10);
		m_grids.at(m_activeGridBuffer)->bindBase(GL_SHADER_STORAGE_BUFFER, 11);
		m_grids.at((m_activeGridBuffer + 1) % 2)->bindBase(GL_SHADER_STORAGE_BUFFER, 12);
		m_explosion->bindVelocity();

		std::chrono::steady_clock::time_point newTime = std::chrono::high_resolution_clock::now();
		long deltaTime = std::chrono::duration_cast<std::chrono::milliseconds>(newTime - m_prevTime).count();
		m_prevTime = newTime;

		m_timeStep = (deltaTime / 1000.0) * m_speedMultiplier;

		simulateProgram->setUniform("maxIdx", uint(m_vertexCount));
		simulateProgram->setUniform("selectedAtomId", selectedAtomId);
		simulateProgram->setUniform("selectedAtomPos", selectedAtomPos);

		simulateProgram->setUniform("MVP", m_viewer->modelViewProjectionTransform());
		simulateProgram->setUniform("invMVP", inverse(m_viewer->modelViewProjectionTransform()));
		simulateProgram->setUniform("invMV", inverse(m_viewer->modelViewTransform()));

		simulateProgram->setUniform("timeStep", m_timeStep);
		simulateProgram->setUniform("fracTimePassed", m_fracTimePassed);

		simulateProgram->setUniform("timeDecay", m_timeDecay);

		simulateProgram->setUniform("xBounds", m_xbounds);
		simulateProgram->setUniform("yBounds", m_ybounds);
		simulateProgram->setUniform("zBounds", m_zbounds);

		simulateProgram->setUniform("springForceActive", m_springActivated);
		simulateProgram->setUniform("springConst", m_springConst);

		simulateProgram->setUniform("gravityVariable", m_gravity);

		simulateProgram->setUniform("repulsionStrength", m_repulsionForce);
		simulateProgram->setUniform("gridResolution", m_gridResolution);

		simulateProgram->setUniform("springToOriginalPos", m_originalPosSpringForce);
		simulateProgram->setUniform("springToOriginalPosConst", m_returnSpringConst);

		simulateProgram->setUniform("mouseAttraction", m_mouseAttraction);
		simulateProgram->setUniform("mouseAttractionSpringConst", m_mouseSpringConst);
		simulateProgram->setUniform("mousePos", mousePos);

		simulateProgram->setUniform("viewDistortion", m_viewDistortion);
		simulateProgram->setUniform("viewDistortionStrength", m_viewDistortionStrength);
		simulateProgram->setUniform("distortionDistCutOff", m_distortionDistCutOff);

		simulateProgram->setUniform("updateOriginalPos", m_updateOriginalPosition);

		simulateProgram->setUniform("stretchForceStrength", m_stretchStrength);
		simulateProgram->setUniform("xStretch", m_xStretch);
		simulateProgram->setUniform("yStretch", m_yStretch);
		simulateProgram->setUniform("zStretch", m_zStretch);

		simulateProgram->dispatchCompute(m_vertexCount, 1, 1);
		simulateProgram->release();

		glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);
		//glMemoryBarrier(GL_TEXTURE_UPDATE_BARRIER_BIT);

		m_explosion->releaseVelocity();
		m_grids.at((m_activeGridBuffer + 1) % 2)->unbind(GL_SHADER_STORAGE_BUFFER);
		m_grids.at(m_activeGridBuffer)->unbind(GL_SHADER_STORAGE_BUFFER);
		m_originalPos->unbind(GL_SHADER_STORAGE_BUFFER);
		//m_randomness->unbind(GL_SHADER_STORAGE_BUFFER);
		m_vertices.at(m_activeBuffer)->unbind(GL_SHADER_STORAGE_BUFFER);
		m_vertices.at((m_activeBuffer + 1) % 2)->unbind(GL_SHADER_STORAGE_BUFFER);

		m_fracTimePassed = m_fracTimePassed >= 1.0 ? m_timeStep - int(m_timeStep) : m_fracTimePassed + m_timeStep - int(m_timeStep);
		//globjects::debug() << m_fracTimePassed;
		
	}
	m_grids.at(m_activeGridBuffer)->setData(m_emptyNeighborhoodList, GL_STREAM_DRAW);

	m_updateOriginalPosition = false;
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
