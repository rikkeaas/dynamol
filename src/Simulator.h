#include <globjects/Buffer.h>
#include <glm/glm.hpp>

namespace dynamol
{
	class Viewer;

	class Simulator
	{
	public:
		Simulator(Viewer* viewer);
		globjects::Buffer* getVertices();
		void Simulator::doStep();
		void simulate();
		bool checkTimeOut();
	private:
		std::vector<std::unique_ptr<globjects::Buffer>> vertices;
		int activeBuffer = 0;

		std::vector<glm::vec4> v_vertices;
		float timeOut;
	};
}