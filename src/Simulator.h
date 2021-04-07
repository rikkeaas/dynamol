#include <globjects/Buffer.h>
#include <glm/glm.hpp>

#include <globjects/VertexArray.h>
#include <globjects/VertexAttributeBinding.h>
#include <globjects/Program.h>
#include <globjects/Shader.h>

#include <chrono>

#include "Renderer.h"
#include "Explosion.h"

namespace dynamol
{
	class Viewer;

	class Simulator : public Renderer
	{
	public:
		Simulator(Viewer* viewer);
		globjects::Buffer* getVertices();

		void doStep();
		void simulate();
		bool checkTimeOut();

		void debug();
		virtual void display();
		

	private:
		glm::vec2 m_xbounds = glm::vec2(0.0, 450.0);
		glm::vec2 m_ybounds = glm::vec2(0.0, 450.0);
		glm::vec2 m_zbounds = glm::vec2(0.0, 450.0);
		float m_springConst = 0.001;
		bool m_springActivated = false;
		float m_gravity = 0.0;
		bool m_gravityActivated = false;
		float m_speedMultiplier = 1.0;
		float m_fracTimePassed = 0.0;
		std::chrono::steady_clock::time_point m_prevTime;


		Viewer* m_viewer;
		bool dummyAnimation = true;
		Explosion* m_explosion;

		std::unique_ptr<globjects::VertexArray> m_vaoQuad = std::make_unique<globjects::VertexArray>();
		std::unique_ptr<globjects::Buffer> m_verticesQuad = std::make_unique<globjects::Buffer>();

		std::vector<std::unique_ptr<globjects::Buffer>> m_vertices;
		int m_activeBuffer = 0;

		std::unique_ptr<globjects::Buffer> m_randomness;
		std::unique_ptr<globjects::Buffer> m_originalPos;
		std::unique_ptr<globjects::Buffer> m_shouldUseZ;

		std::unique_ptr<globjects::VertexArray> m_vao = std::make_unique<globjects::VertexArray>();
		float m_vertexCount;

		float m_timeOut;
		float m_timeStep;

		std::unique_ptr<globjects::Texture> m_colorTexture = nullptr;
	};
}