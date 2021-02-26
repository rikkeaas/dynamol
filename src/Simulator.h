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

		std::vector<std::unique_ptr<globjects::Buffer>> vertices;
		int activeBuffer = 0;

		std::unique_ptr<globjects::VertexArray> m_vao = std::make_unique<globjects::VertexArray>();
		int vertexCount;

		std::vector<glm::vec4> v_vertices;
		float timeOut;

		std::unique_ptr<globjects::Texture> m_colorTexture = nullptr;
	};
}