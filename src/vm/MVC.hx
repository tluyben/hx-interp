package vm;

/**************** Embed MVC System ****************
 ******* Register & retrive mvc components ********
 ******* Notification & observer system ***********
 **************************************************
 ******* Please obey the basic mvc rules **********
 ******* Proxy don't observe notification *********
 ******* Proxy only send notification *************
 ******* Proxy only retrieve proxy ****************
 ******* Mediator retrieve M & P ******************
 ******* Mediator can observe notification ********
 ******* Mediator can send notification ***********
 ******* Command retrieve all *********************
 ******* Command reponse to notification **********
 ******* Command can send notification ************
***************************************************/

class MVC
{
	static var proxyMap:Map<String, Dynamic>;
	static var mediatorMap:Map<String, Dynamic>;
	static var commandMap:Map<String, Dynamic>;
	static var observerMap:Map<String, Array<Observer>>;
	
	public static function initialize()
	{
		proxyMap = new Map<String, Dynamic>();
		mediatorMap = new Map<String, Dynamic>();
		commandMap = new Map<String, Dynamic>();
		observerMap = new Map<String, Array<Observer>>();
	}
	
	public static function _finalize()
	{
		proxyMap = null;
		mediatorMap = null;
		commandMap = null;
		observerMap = null;
	}
	
	public static function registerCommand(notificationName:String, cmd:Dynamic, ?priority:Int = 0):Void
	{
		if (commandMap.exists(notificationName)) return;
		commandMap.set(notificationName, true);
		registerObserver(notificationName, cmd, priority);
	}

	public static function removeCommand(notificationName:String, cmd:Dynamic):Void
	{
		if (commandMap.exists(notificationName))
		{
			commandMap.remove(notificationName);
			removeObserver(notificationName, cmd);
		}
	}

	public static function hasProxy(proxyName:String):Bool
	{
		return proxyMap.exists(proxyName);
	}

	public static function registerProxy(proxyName:String, proxy:Dynamic):Void
	{
		proxyMap.set(proxyName, proxy);
	}

	public static function retrieveProxy(proxyName:String):Dynamic
	{
		return proxyMap.get(proxyName);
	}

	public static function removeProxy(proxyName:String):Dynamic
	{
		var proxy:Dynamic = proxyMap.get(proxyName);
		if (proxy != null) proxyMap.remove(proxyName);
		return proxy;
	}

	public static function hadMediator(mediatorName:String):Bool
	{
		return mediatorMap.exists(mediatorName);
	}

	public static function registerMediator(mediatorName:String, mediator:Dynamic):Void
	{
		mediatorMap.set(mediatorName, mediator);
	}

	public static function retrieveMediator(mediatorName:String):Dynamic
	{
		return mediatorMap.get(mediatorName);
	}

	public static function removeMediator(mediatorName:String):Dynamic
	{
		var mediator:Dynamic = mediatorMap.get(mediatorName);
		if (mediator != null) mediatorMap.remove(mediatorName);
		return mediator;
	}

	public static function sendNotification(notificationName:String, ?data:Dynamic = null):Void
	{
		var notification:Notification = new Notification();
		notification.name = notificationName;
		notification.data = data;
		notification.propagating = true;
		notifyObservers(notification);
	}

	public static function registerObserver(notificationName:String, listener:Dynamic, priority:Int = 0):Void
	{
		var observer:Observer = new Observer();
		observer.notify = listener;
		observer.priority = priority;
		
		if (!observerMap.exists(notificationName))
			observerMap.set(notificationName, new Array<Observer>());

		var observers:Array<Observer> = observerMap.get(notificationName);
		observers.push(observer);
		observers.sort(sortObservers);
	}

	public static function removeObserver(notificationName:String, listener:Dynamic):Void
	{
		var observers:Array<Observer> = observerMap.get(notificationName);
		var observer:Observer;
		for (i in 0...observers.length)
		{
			observer = observers[i];
			if (observer.notify == listener)
			{
				observers.splice(i, 1);
				observer.notify = null;
				observer.priority = 0;
				break;
			}
		}

		if (observers.length == 0)
			observerMap.remove(notificationName);
	}

	static function notifyObservers(notification:Notification):Void
	{
		if (observerMap.exists(notification.name))
		{
			var observers:Array<Observer> = observerMap.get(notification.name);
			for (i in 0...observers.length)
			{
				if (!notification.propagating)
				{
					break;
				}
				observers[i].notify(notification);
			}
		}
		notification.data = null;
		notification.name = null;		
	}
	
	static function sortObservers(observer1:Observer, observer2:Observer):Int
	{
		if (observer1.priority > observer2.priority)
			return -1;
		else if (observer1.priority < observer2.priority)
			return 1;
		else
			return 0;
	}
}

class Observer
{
	public var notify:Dynamic;
	public var priority:Int;
	
	public function new()
	{
	}
}

class Notification
{
	public var name:String;
	public var data:Dynamic;
	public var propagating:Bool;
	
	public function new()
	{
	}
}
