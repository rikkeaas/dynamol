#include <globjects/Buffer.h>
#include <glm/glm.hpp>

#include <globjects/VertexArray.h>
#include <globjects/VertexAttributeBinding.h>
#include <globjects/Program.h>
#include <globjects/Shader.h>

#include "Renderer.h"

namespace dynamol
{
	class Viewer;

	class Simulator : public Renderer
	{
	public:
		Simulator(Viewer* viewer);
		globjects::Buffer* getVertices();

		void Simulator::doStep();
		void simulate();
		bool checkTimeOut();

		void debug();
		virtual void display();
		

	private:

		std::unique_ptr<globjects::VertexArray> m_vaoQuad = std::make_unique<globjects::VertexArray>();
		std::unique_ptr<globjects::Buffer> m_verticesQuad = std::make_unique<globjects::Buffer>();

		std::vector<std::unique_ptr<globjects::Buffer>> m_vertices;
		int m_activeBuffer = 0;

		std::unique_ptr<globjects::Buffer> m_randomness;
		std::unique_ptr<globjects::Buffer> m_shouldUseZ;

		std::unique_ptr<globjects::VertexArray> m_vao = std::make_unique<globjects::VertexArray>();
		float m_vertexCount;

		float m_timeOut;
		float m_timeStep;

		std::unique_ptr<globjects::Texture> m_colorTexture = nullptr;
	};
}