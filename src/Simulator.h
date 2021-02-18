#include <globjects/Buffer.h>

namespace dynamol
{
	class Viewer;

	class Simulator
	{
	public:
		Simulator(Viewer* viewer);
		globjects::Buffer* getVertices();
		void simulate();
		bool checkTimeOut();
	private:
		globjects::Buffer* curr_vertices;
		globjects::Buffer* prev_vertices;

		float timeOut;
	};
}