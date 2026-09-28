from abc import ABC, abstractmethod
import time
from palette import Palette

class BaseTarget(ABC):
    @property
    @abstractmethod
    def name(self) -> str:
        pass

    @abstractmethod
    def generate(self, palette: Palette) -> None:
        """Write configuration files to disk."""
        pass

    @abstractmethod
    def apply(self) -> None:
        """Trigger native live-reload without restarting the application."""
        pass

    def update(self, palette: Palette) -> bool:
        """Execute generate + apply with timing and safe isolation."""
        t0 = time.time()
        try:
            self.generate(palette)
            self.apply()
            dt = (time.time() - t0) * 1000
            print(f"  ✓ [{self.name}] updated successfully ({dt:.1f}ms)")
            return True
        except Exception as e:
            dt = (time.time() - t0) * 1000
            print(f"  ✗ [{self.name}] update failed ({dt:.1f}ms): {e}")
            return False
