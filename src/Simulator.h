#include <globjects/Buffer.h>

namespace dynamol
{
	class Viewer;

	class Simulator
	{
	public:
		Simulator(Viewer* viewer);
		std::unique_ptr<globjects::Buffer> getVertices();
	private:
		globjects::Buffer* curr_vertices;
		globjects::Buffer* prev_vertices;
	};
}