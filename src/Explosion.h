#include <globjects/Buffer.h>
#include "Renderer.h"
#include "Viewer.h"
#include <imgui.h>

namespace dynamol
{
	class Viewer;

	class Explosion : public Renderer
	{
	public:
		Explosion(Viewer* viewer);
		~Explosion();
		virtual void display();
		void bindVelocity();
		void releaseVelocity();

	private:
		Viewer* m_viewer;

		float m_speed = 10.0;

		float m_x = 0.0;
		float m_y = 0.0;
		float m_z = 0.0;

		glm::vec3 m_maxBounds;
		glm::vec3 m_minBounds;

		bool m_explode = false;
		bool m_update = true;

		std::unique_ptr<globjects::Buffer> m_velocity;
	};
}