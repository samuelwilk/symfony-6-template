<?php

namespace App\Tests;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;
use Symfony\Component\HttpFoundation\Response;

class smokeTest extends WebTestCase
{
    // test that localhost returns a 200
    // @todo: delete this
    public function testLocalhost()
    {
        // This calls KernelTestCase::bootKernel(), and creates a
        // "client" that is acting as the browser
        $client = static::createClient();

        // Request a specific page
        $client->request('GET', '/');

        // Validate a successful response and some content
        $this->assertResponseStatusCodeSame(Response::HTTP_NOT_FOUND);
        $this->assertSelectorTextContains('h1', 'Welcome to Symfony');
    }
}
