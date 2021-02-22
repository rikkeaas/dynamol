#include <globjects/Buffer.h>
#include <glm/glm.hpp>

#include <globjects/VertexArray.h>
#include <globjects/VertexAttributeBinding.h>

namespace dynamol
{
	class Viewer;

	class Simulator
	{
	public:
		Simulator(Viewer* viewer);
		globjects::Buffer* getVertices();

		void draw();

		void Simulator::doStep();
		void simulate();
		bool checkTimeOut();
	private:
		std::vector<std::unique_ptr<globjects::Buffer>> vertices;
		int activeBuffer = 0;

		std::unique_ptr<globjects::VertexArray> m_vao = std::make_unique<globjects::VertexArray>();
		int vertexCount;

		std::vector<glm::vec4> v_vertices;
		float timeOut;
	};
}