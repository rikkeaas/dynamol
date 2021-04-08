
#include "Explosion.h"
#include "Protein.h"
#include <globjects/State.h>

using namespace dynamol;
using namespace glm;
using namespace gl;
using namespace globjects;

Explosion::Explosion(Viewer* viewer) : Renderer(viewer)
{
	m_viewer = viewer;
	m_velocity = Buffer::create();
	auto timestep = viewer->scene()->protein()->atoms();
	std::vector<vec4> zeros;
	for (int i = 0; i < timestep[0].size(); i++)
	{
		zeros.push_back(vec4(0.0));
	}

	m_velocity->setData(zeros, GL_STREAM_DRAW);
	int size = zeros.size();
	globjects::debug() << "Creating explosion " << size;

	m_minBounds = viewer->scene()->protein()->minimumBounds();
	m_maxBounds = viewer->scene()->protein()->maximumBounds();

	m_x = 0.5 * (m_minBounds.x + m_maxBounds.x);
	m_y = 0.5 * (m_minBounds.y + m_maxBounds.y);
	m_z = 0.5 * (m_minBounds.z + m_maxBounds.z);
}

Explosion::~Explosion() 
{
}

void Explosion::display()
{
	if (ImGui::BeginMenu("Explosion"))
	{
		if (!m_explode)
		{
			ImGui::SliderFloat("Explosion center x: ", &m_x, m_minBounds.x, m_maxBounds.x);
			ImGui::SliderFloat("Explosion center y: ", &m_y, m_minBounds.y, m_maxBounds.y);
			ImGui::SliderFloat("Explosion center z: ", &m_z, m_minBounds.z, m_maxBounds.z);
			ImGui::SliderFloat("Decay of velocity with time: ", &m_timeDecay, 0.9, 1.1);
			ImGui::SliderFloat("Explosion speed: ", &m_speed, 1.0, 100.0);
		}
		ImGui::Checkbox("Explode: ", &m_explode);
		ImGui::EndMenu();
	}
	
	if (!m_explode && !m_update)
	{
		m_update = true;
		auto timestep = m_viewer->scene()->protein()->atoms()[0];
		std::vector<vec4> zeros;
		for (int i = 0; i < timestep.size(); i++)
		{
			zeros.push_back(vec4(0.0));
		}

		m_velocity->setData(zeros, GL_STATIC_DRAW);
	}
	
	if (m_explode && m_update)
	{
		m_update = false;
		auto timestep = m_viewer->scene()->protein()->atoms()[0];
		std::vector<vec4> velocityPerAtom;

		for (int i = 0; i < timestep.size(); i++)
		{
			vec3 centerToAtom = vec3(timestep[i]) - vec3(m_x, m_y, m_z);
			float dist = length(centerToAtom);
			vec3 velocity = normalize(centerToAtom) * (m_speed / dist);
			//globjects::debug() << velocity.x << " " << velocity.y << " " << velocity.z;
			//centerToAtom = normalize(centerToAtom);
			velocityPerAtom.push_back(vec4(velocity, 0.0));
		}

		m_velocity->setData(velocityPerAtom, GL_STREAM_DRAW);
	}
	
}


void Explosion::bindVelocity()
{
	m_velocity->bindBase(GL_SHADER_STORAGE_BUFFER, 12);
}

void Explosion::releaseVelocity()
{
	m_velocity->unbind(GL_SHADER_STORAGE_BUFFER);
}

float Explosion::getTimeDecay()
{
	return m_timeDecay;
}